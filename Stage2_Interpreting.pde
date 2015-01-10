import com.jonwohl.*;
import processing.video.*;
import gab.opencv.*;

Attention attention;
Capture cam;
PImage out;
PImage src, dst;
OpenCV opencv;
ArrayList<Contour> contours;

int camW = 640;
int camH = 480;

Image sample;
ArrayList<Image> models;
FloatList distances;
FloatList distancesR; //reverse order
FloatList diffDistances; //absolute value of the d-dR
FloatList definitive;
int ratio = 4;
color green = color(0, 255, 0);
color ghost = color(255, 50);
color white = color(255);
PFont f;
int numModels;
int currentModel = 0;
int nearest;
int smallW;
int smallH;
float confidence = 0;
float confidenceThres = 0;
float confidenceStep = 0;
int counter = 0;
int counterMax = 140;
int counterFound = 0;
int counterFoundMax = 250;
int counterCursor = 0;
int counterCursorMax = 60;

// record a new image and recalculate nearest neighbor -- press 'r' to record
boolean newImage = false;
// show what the camera is seeing -- press 'v' to toggle
boolean camView = true;
// compare the saple with the models
boolean comparing = false;
// shows small slow res images on top left corner
boolean debugView = false;
// a model with a level of confidence over the threshold is found
boolean matchFound = false;
// wait with a cursor until a rectangle blob 'image sent' is detected
boolean waiting = false;
// whether or not to invert the thresholded image -- press 'i' to toggle
boolean invert = false;
boolean cursorON = true;
int dir; //0 sample against model / 1 model against sample

void setup() {
  size(1024/2, 768/2); // 512, 384

  //size(1280, 1024);
  background(0);
  smooth();

  // For ODroid
  //  cam = new Capture(this, 320, 240, "/dev/video0", 30);

  // For Mac
  cam = new Capture(this, 640, 480);
  cam.start();
  // PImage dst = createImage(640, 480, RGB);
  // instantiate focus passing an initial input image
  attention = new Attention(this, cam);
  out = attention.focus(cam, cam.width, cam.height);
  f = loadFont( "Inconsolata-Regular-14.vlw" );
  textFont(f);  

  // load all the model images and calculate its features
  java.io.File modelFolder = new java.io.File(dataPath("models"));
  String[] modelFilenamesTemp = modelFolder.list();
  sample = new Image();
  models = new ArrayList<Image>();
  for (int i = 0; i < modelFilenamesTemp.length; i++) {
    if (!modelFilenamesTemp[i].startsWith(".")) {
      models.add(new Image());
      models.get(i).filename = "models/" + modelFilenamesTemp[i];
      models.get(i).update();
      models.get(i).calculateFeatures();
      println("maxX " + i + ": " + models.get(i).maxX);
    }
  }
  smallW = int(width / ratio);
  smallH = int(height / ratio);
  numModels = models.size();
  distances = new FloatList();
  distancesR = new FloatList();
  diffDistances = new FloatList();
  definitive = new FloatList(); // weighted result.

  // to delete after testing
  newImage = true;
  camView = false;
}

void draw() {

  if (camView) {
    if (cam.available()) {
      // read a new frame
      cam.read();
      // warp using library. invert if needed -- toggle with 'i'
      warpImage();
    }
  } else if (newImage) {
    background(0);
    reset();
    loadNewSample();
    newImage = false;
    comparing = true;
  } else if (comparing) {
    readConfidenceThres();
    drawConfidence();
    if (counter == 0) {
      background(0);
      // calculate centering vectors of models to new sample. center the WhitePix
      models.get(currentModel).calcCentering(sample.cog);
      models.get(currentModel).centerImage(sample.cog);

      // tests with blend
      //image(sample.imgLarge, 0, 0);
      //blend(models.get(currentModel).imgLarge, 0, 0, width, height, 0, 0, width, height, SUBTRACT);

      // display the model, centered to the sample
      models.get(currentModel).display(int(models.get(currentModel).centering.x)*ratio, int(models.get(currentModel).centering.y)*ratio, white);
      
      // display the new sample
      sample.display(0, 0, ghost);

      // calculate distances to sample
      calculateDist(currentModel);
      confidence = map(definitive.get(currentModel), 5000, 30000, 100, 0);
      println("confidence: " + confidence);
      println("confidenceThres: " + confidenceThres);
      confidenceStep = 0;
      newImage = false;
      println("currentModel: " + currentModel + "  numModels: " + numModels);
      counter++;
    } else if (counter < counterMax && counter != 0) {
      counter++;
    } else if (counter >= counterMax){
      if (confidence > confidenceThres){
        comparing = false;
        matchFound = true;
        counterFound = 0;
      } else if (currentModel < numModels - 1) {
      counter = 0;
      currentModel++;
      } else if (currentModel == numModels - 1) {
      //comparing = false;
      counter = 0;
      currentModel = 0;
      }
    }
    if (debugView && counter !=0) {
      //display features
      sample.displayFeatures(green);
      models.get(currentModel).displayFeatures(white);
      // display small images with WhitePixels
      //sample.displayWhitePix();
      sample.displayFeaturesSmall(green);
      models.get(currentModel).displayFeaturesSmall(white);
      //models.get(currentModel).displayWhitePixCentered();
      // display the Small images
      //models.get(0).displaySmall(white);
      //sample.displaySmall(white);
    }
  } else if (matchFound){
    if (counterFound < counterFoundMax*0.5){
      models.get(currentModel).display(int(models.get(currentModel).centering.x)*ratio, int(models.get(currentModel).centering.y)*ratio, white);
      counterFound++;
    } else if (counterFound >= counterFound*0.6){
      noStroke();
      fill(0, 10);
      rect(0, 0, width, height);
      counterFound++;
      if (counterFound >= counterFoundMax){
        matchFound = false;
        waiting = true;
        counter = 0;
        println("END OF FOUND");
      }
    }
  } else if (waiting){
    println("WAITING");
    if (counterCursor == counterCursorMax){
      cursorON = !cursorON;
      counterCursor = 0;
    }
    if (cursorON){
      fill(255);
      rectMode(CENTER);
      rect(width/2, height/2, 40, 40);
      rectMode(CORNER);
    } else {
      background(0);
    }
    counterCursor++;
  }
}

void readConfidenceThres() {
  confidenceThres = map(mouseY, 0, height, 100, 0);
}

void drawConfidence() {
  noStroke();
  fill(0);
  rect(width-50, 0, width, height);
  stroke(255);
  noFill();
  rect(width-30, height-40, 10, -(height-80));
  // draw confidence threshold
  stroke(255);
  line(width-40, map(confidenceThres, 0, 100, height-40, 40), width-10, map(confidenceThres, 0, 100, height-40, 40));
  fill(255);
  confidenceStep = confidenceStep + (confidence - confidenceStep)*0.05;
  rect(width-30, height-40, 10, -(map(confidenceStep, 0, 100, 0, height - 80)));
}

void calculateDist(int modelNum) {
  distances.append(nn(sample.whitePix, models.get(modelNum).whitePixCentered, modelNum, 0));
  distancesR.append(nn(models.get(modelNum).whitePixCentered, sample.whitePix, modelNum, 1));
  println("distance: " + distances.get(modelNum) + "  distanceR: " + distancesR.get(modelNum));
  calculateDiff(modelNum);
  calculateDefinitive(modelNum);
  println("Diff: " + diffDistances.get(modelNum) + "  Definitive: " + definitive.get(modelNum));
  if (definitive.get(modelNum) == definitive.min()) {
    nearest = modelNum; //this saves the index of the closest model.
  }
}

void calculateDiff(int modelNum) {
  diffDistances.append(abs(distances.get(modelNum) - distancesR.get(modelNum)));
  if (debugView){
    pushMatrix();
    translate(width-120, height - 60);
    fill(255);
    text(diffDistances.get(modelNum), 0, 0);
    popMatrix();
  }
}

void calculateDefinitive(int modelNum) {
  definitive.append(distances.get(modelNum) + distancesR.get(modelNum) + diffDistances.get(modelNum));
  if (debugView){
    pushMatrix();
    translate(width - 120, height-40);
    fill(255);
    text(definitive.get(modelNum), 0, 0);
    popMatrix();
  }
}

float nn (ArrayList<PVector> arraySample, ArrayList<PVector> arrayModel, int pos, int dir) {
  float totalDist = 0;
  PVector closest = new PVector(0, 0);
  int posX = pos%(ratio);
  int posY = pos/(ratio);
  for (int i = 0; i < arraySample.size (); i++) {
    float dist = 100000000; // set to large number initially. no need to store.
    PVector s = arraySample.get(i);
    for (int j = 0; j < arrayModel.size (); j++) {
      PVector m = arrayModel.get(j);
      float thisDist = dist(s.x, s.y, m.x, m.y);

      if (thisDist < dist) {
        dist = thisDist;
        closest = new PVector(m.x, m.y);
      }
    }
    if (debugView){
      color c;
      if (dir == 0) {
        c = color(0, 255, 0, 30);
      } else {
        c = color(255, 0, 255, 30);
      }
      stroke(c);
      //pushMatrix();
      //translate(imageW*posX, imageH*posY);
      line(s.x, s.y, closest.x, closest.y);
      fill(0, 255, 255);
      //popMatrix();
    }
    totalDist += dist;
  }
  // Print the distances, one way and the other.
  if (debugView){
    pushMatrix();
    if (dir == 0) {
      translate(width - 120, height-80);
      fill(0, 255, 0);
    } else {
      translate(width - 120, height-100);
      fill(255, 0, 255);
    } 
  
    text(totalDist, 0, 0);
    popMatrix();
  }
  return totalDist;
}

void reset(){
  confidence = 0;
  confidenceThres = 0;
  confidenceStep = 0;
  resetArrays();
}

void resetArrays() {
  distances.clear();
  distancesR.clear();
  diffDistances.clear();
  definitive.clear();
}

void loadNewSample() {
  //sample.filename = "sample.jpg";
  sample.filename = "sample.png"; // static image for testing
  sample.update();
  sample.reset();
  sample.calculateFeatures();
  sample.centerImage(sample.cog);
  sample.centering = new PVector(0, 0);
}

void warpImage() {
  // warp the selected region on the input image (cam) to an output image of width x height
  out = attention.focus(cam, cam.width, cam.height);
  image(out, 0, 0);
  float thresh = map(mouseX, 0, height, 0, 1.0);
  filter(THRESHOLD, thresh);
  if (invert) {
    filter(INVERT);
  }
}

void keyPressed() {
  if (key == 'R' || key == 'r') {
    //saveFrame("/Users/ishac/Documents/Processing/Stage2_Interpreting/data/sample.jpg");
    newImage = true;
    camView = false;
    waiting = false;
  } else if (key == 'V' || key == 'v') {
    camView = true;
  } else if (key == 'D' || key == 'd') {
    debugView = !debugView;
  }
  // do or don't invert input
  if (key == 'i' || key == 'I') {
    invert = !invert;
  }
}

