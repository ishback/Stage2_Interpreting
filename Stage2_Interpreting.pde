import com.jonwohl.*;
import processing.video.*;
import gab.opencv.*;

Attention attention;
Capture cam;
PImage out;
PImage src, dst;
PImage temp, prevTemp;
PVector centroid, prevCentroid;
OpenCV opencv;
// A list of all the contours found by OpenCV
ArrayList<Contour> contours;

int displayW = 1024;
int displayH = 768;
int camW = 320;
int camH = 240;

PImage fullSizeSample;
Image smallSample;
ArrayList<PImage> fullSizeModels;
ArrayList<Image> smallModels;
ArrayList<Image> resizedModels;

FloatList distances;
FloatList distancesR; //reverse order
FloatList diffDistances; //absolute value of the d-dR
FloatList definitive;

int ratio = 4;

color green = color(0, 255, 0);
color ghost = color(255, 50);
color white = color(255);

PFont f;
PFont bold;
PFont text;

int numModels;
int currentModel = 0;
int closestModel = 0;
int nearest;

float confidence = 0;
float confidenceThres = 90;
float confidenceStep = 0;
int counter = 0;
int counterMax = 140;
int counterFound = 0;
int counterFoundMax = 250;
int counterCursor = 0;
int counterCursorMax = 60;
int counterWatching = 0;
int counterWatchingMax = 10;
int counterImageChanging = 0;
int counterImageChangingMax = 10; // freq of checking new image is counterWatchingMax*counterImageChangingMax
int counterTransitioning = 0;
int counterTransitioningWait1 = 140;
int counterTransitioningFade = 200;
int counterTransitioningWait2 = 260;
int prevNumPixels = 0;
int numPixels = 0;
int thresNumPixels = 5000;
String name;

ArrayList<Float> confidences;

// record a new image and recalculate nearest neighbor -- press 'r' to record
boolean newImage = false;
// show what the camera is seeing -- press 'v' to toggle
boolean camView = true;
boolean transitioning = false;
// compare the saple with the models
boolean comparing = false;
// shows small slow res images on top left corner
boolean debugView = false;
// a model with a level of confidence over the threshold is found
boolean matchFound = false;
// wait with a cursor until a rectangle blob 'image sent' is detected
boolean waiting = false;
// whether or not to invert the thresholded image -- press 'i' to toggle
boolean invert = true;
boolean cursorON = true;
boolean imageHasChanged = false;
int dir; //0 sample against model / 1 model against sample


/////////////////////////////////////////////////////////////////////////////  SETUP
void setup() {
  size(displayW, displayH);
  background(0);

  // For ODroid
  //  cam = new Capture(this, 320, 240, "/dev/video0", 30);

  // For Mac
  cam = new Capture(this, camW, camH);
  //cam = new Capture(this, 640, 480, "Logitech Camera", 30);
  cam.start();
  
  // instantiate focus passing an initial input image
  attention = new Attention(this, cam);
  out = attention.focus(cam, cam.width, cam.height);
  opencv = new OpenCV(this, out);
  
  f = loadFont( "Inconsolata-Regular-14.vlw" );
  text = loadFont("FuturaStd-Book-26.vlw");
  bold = loadFont("FuturaStd-ExtraBold-48.vlw");
  textFont(f);
  textFont(bold);

  // load all the model images and calculate its features
  java.io.File modelFolder = new java.io.File(dataPath("models"));
  String[] modelFilenamesTemp = modelFolder.list();
//  fullSizeSample = createImage(camW, camH, RGB);
  fullSizeModels = new ArrayList<PImage>();
  smallModels = new ArrayList<Image>();
  resizedModels = new ArrayList<Image>();
  
  confidences = new ArrayList<Float>();
  for (int i = 0; i < modelFilenamesTemp.length; i++) {
    if (!modelFilenamesTemp[i].startsWith(".")) {
      String filename = "models/" + modelFilenamesTemp[i];
      fullSizeModels.add(loadImage(filename));
      smallModels.add(new Image(fullSizeModels.get(i), displayW/ratio, displayH/ratio));
      smallModels.get(i).filename = filename;
    }
  }
  
  
  numModels = fullSizeModels.size();
  distances = new FloatList();
  distancesR = new FloatList();
  diffDistances = new FloatList();
  definitive = new FloatList(); // weighted result.

  // to delete after testing
  newImage = false;
  camView = false;
}

/////////////////////////////////////////////////////////////////////////////  DRAW
void draw() {
  counterWatching++;
  if (counterWatching >= counterWatchingMax){
    if (cam.available()) {
      // read a new frame
      cam.read();
      warpImage();
      //image(out, 0, 0);
      
      numPixels = countPixels(out);
      //println("numPixels: " + numPixels);
      //println("prevNumPixels: " + prevNumPixels);
      
      
      if ((numPixels > prevNumPixels*1.2 || numPixels*1.5 < prevNumPixels) && numPixels > thresNumPixels){
        imageHasChanged = true;
        prevNumPixels = numPixels;
        println("IMAGE HAS CHANGED");
        counterImageChanging = 0;
      }
      if (imageHasChanged){
        if (counterImageChanging < counterImageChangingMax){
          counterImageChanging++;
          println("counterImageChanging: " + counterImageChanging);
          background(0);
          waiting = true;
          transitioning = false;
          comparing = false;
        } else { // image has changed and has been stable for a while -> use it as new sample
          image(out, 0, 0);
          out.save("/Users/ishac/Documents/Processing/Stage2_Interpreting/data/sample.png");
          newImage = true;
          println("NEW IMAGE SAVED");
          counterImageChanging = 0;
          imageHasChanged = false;
          currentModel = 0;
          confidences.clear();
          closestModel = 0;
        }
      }
    }
    counterWatching = 0;
  }
  if (newImage) {
    reset();
    loadNewSample();
    background(0);
    image(out, 0, 0);
    newImage = false;
    transitioning = true;
  } else if (transitioning){
    println("counterTransitioning: " + counterTransitioning);
    if (counterTransitioning <= counterTransitioningWait1){
      counterTransitioning++;
    } else if (counterTransitioning <= counterTransitioningFade){
      fill(0, 5);
      rect(0, 0, width, height);
      counterTransitioning++;
    } else if (counterTransitioning <= counterTransitioningWait2){
      counterTransitioning++;
    } else if (counterTransitioning > counterTransitioningWait2){
      comparing = true;
      transitioning = false;
      counterTransitioning = 0;
    }
  } else if (comparing) {
    readConfidenceThres();
    
    if (counter == 0) {
      background(0);
      Image currSmallModel = smallModels.get(currentModel);
      // calculate centering vectors of models to new sample. center the WhitePix
//      currModel.calcCentering(sample.cog);
//      currModel.centerImage(sample.cog);

      float sampleToModelRatioW = currSmallModel.bb.width / smallSample.bb.width;
      float sampleToModelRatioH = currSmallModel.bb.height / smallSample.bb.height;

      Image resizedModelImage = new Image(loadImage(smallModels.get(currentModel).filename), int(sampleToModelRatioW * displayW/ratio), int(sampleToModelRatioH * displayH/ratio));

      //  from small model to resized model
      float resizeRatioW = resizedModels.get(currentModel).getWidth() / currSmallModel.getWidth();
      float resizeRatioH = resizedModels.get(currentModel).getHeight() / currSmallModel.getHeight();

      // using the new width and height of the small resized MODEL, create a big resized model for display 
      PImage bigResizedModel = loadImage(smallModels.get(currentModel).filename);
      bigResizedModel.resize(resizedModelImage.getWidth()*ratio, resizedModelImage.getHeight()*ratio);
      
      imageMode(CENTER);
      PVector bigResizedCenterModel = new PVector(resizedModelImage.getCenter().x * ratio, resizedModelImage.getCenter().y * ratio);
      tint(white);
      image(bigResizedModel, displayW/2 - bigResizedCenterModel.x, displayH/2 - bigResizedCenterModel.y);
      
      // using the new width and height of the small resized SAMPLE, create a big resized sample for display 
      PImage bigResizedSample = loadImage(smallSample.filename);
      
      PVector bigResizedCenterSample = new PVector(smallSample.getCenter().x * ratio, smallSample.getCenter().y * ratio);
      tint(ghost);
      image(bigResizedSample, displayW/2 - bigResizedCenterSample.x, displayH/2 - bigResizedCenterSample.y);
      
      
      // calculate distances to sample
      calculateDist(currentModel);
      confidence = map(definitive.get(currentModel), 5000, 60000, 100, 0);
      confidences.add(confidence);
      if (confidence > confidences.get(closestModel)){
        closestModel = currentModel;
      }
      println("confidence: " + confidence);
      println("confidenceThres: " + confidenceThres);
      confidenceStep = 0;
      newImage = false;
      println("currentModel: " + currentModel + "  numModels: " + numModels);
      counter++;
    } else if (counter < counterMax && counter != 0) {
      counter++;
    } else if (counter >= counterMax){
//      if (confidence > confidenceThres){
//        comparing = false;
//        matchFound = true;
//        counterFound = 0;
//        String[] q = splitTokens(models.get(currentModel).filename, "/");
//        println(q[1]);
//        String[] t = splitTokens(q[1], ".");
//        name = new String(t[0]);
//      } else 
      if (currentModel < numModels - 1) {
      counter = 0;
      currentModel++;
      } else if (currentModel == numModels - 1) {
      comparing = false;
      matchFound = true;
      counter = 0;
      counterFound = 0;
      currentModel = 0;
      }
    }
    //if (debugView && counter !=0) {
    if (debugView) {
      //display features
      //sample.displayFeatures(green);
      //models.get(currentModel).displayFeatures(white);
      // display small images with WhitePixels
      //sample.displayWhitePix();
      //sample.displayFeaturesSmall(green);
      //models.get(currentModel).displayFeaturesSmall(white);
      //models.get(currentModel).displayWhitePixCentered();
      // display the Small images
      //models.get(0).displaySmall(white);
      //sample.displaySmall(white);
      showTrueView();
      drawConfidence();
      drawBars();
      pushMatrix();
      translate(width - 120, height-60);
      fill(255, 0, 255);
      textFont(f);
      text(confidence, 0, 0);
      popMatrix();
    }
  } else if (matchFound){
    if (counterFound < counterFoundMax*0.5){
      //models.get(currentModel).display(int(models.get(currentModel).centering.x)*ratio, int(models.get(currentModel).centering.y)*ratio, white);
      background(0);
      sample.display(0, 0, ghost);
      String[] q = splitTokens(models.get(closestModel).filename, "/");
      println(q[1]);
      String[] t = splitTokens(q[1], ".");
      name = new String(t[0]);
      fill(255);
      textAlign(CENTER, CENTER);
      textFont(text);
      text("This looks like a", width/2, height/2 - 50);
      textFont(bold);
      text(name, width/2, height/2);
      counterFound++;
    } else if (counterFound >= counterFound*0.6){
      noStroke();
      fill(0, 10);
      rect(0, 0, width, height);
      counterFound++;
      if (counterFound >= counterFoundMax){
        matchFound = false;
        //waiting = true;
        counter = 0;
        println("END OF FOUND");
      }
    }
  } else if (waiting){
    //println("WAITING");
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
  
  //image(out, width/4, 0, width/4, height/4);
}


/////////////////////////////////////////////////////////////////////////////  FUNCTIONS
void showTrueView(){
  image(out, 0, 0, width/4, height/4);
}

void readConfidenceThres() {
  confidenceThres = map(mouseY, 0, height, 100, 0);
}

void drawConfidence() {
  noStroke();
  fill(0);
  rect(width-50, 0, width, height);
  stroke(0, 255, 0);
  noFill();
  rect(width-30, height-40, 10, -(height-80));
  // draw confidence threshold
  stroke(0, 255, 0);
  line(width-40, map(confidenceThres, 0, 100, height-40, 40), width-10, map(confidenceThres, 0, 100, height-40, 40));
  fill(0, 255, 0);
  confidenceStep = confidenceStep + (confidence - confidenceStep)*0.05;
  rect(width-30, height-40, 10, -(map(confidenceStep, 0, 100, 0, height - 80)));
}

void drawBars(){
  noStroke();
  for (int i=0; i < confidences.size(); i++){
    image(models.get(i).imgSmall, 5, 36 + i*30 + 300, 20, 16);
    if (i == closestModel){
      fill(0, 255, 0);
    } else {
      fill(250);
    }
    if (i == currentModel){
      confidenceStep = confidenceStep + (confidences.get(i) - confidenceStep)*0.05;
      rect(30, 40 + i*30 + 300, confidenceStep, 10);
    } else {
      rect(30, 40 + i*30 + 300, confidences.get(i), 10);
    }
    
    println("confidence " + i + "= " + confidences.get(i));
  }
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
//  if (debugView){
//    pushMatrix();
//    translate(width-120, height - 60);
//    fill(255);
//    text(diffDistances.get(modelNum), 0, 0);
//    popMatrix();
//  }
}

void calculateDefinitive(int modelNum) {
  definitive.append(distances.get(modelNum) + distancesR.get(modelNum) + diffDistances.get(modelNum));
//  if (debugView){
//    pushMatrix();
//    translate(width - 120, height-40);
//    fill(255);
//    text(definitive.get(modelNum), 0, 0);
//    popMatrix();
//  }
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
      //stroke(c);
      //line(s.x, s.y, closest.x, closest.y);
      //line((s.x+sample.centering.x)*ratio, (s.y+sample.centering.y)*ratio, (closest.x+models.get(pos).centering.x)*ratio, (closest.y+models.get(pos).centering.y)*ratio);
      if (dir==0){
        stroke(0, 255, 0);
        line((s.x)*ratio, (s.y)*ratio, (closest.x)*ratio, (closest.y)*ratio);
      }
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
    textFont(f);
    text(totalDist, 0, 0);
    popMatrix();
  }
  return totalDist;
}

void reset(){
  confidence = 0;
  //confidenceThres = 0;
  confidenceStep = 0;
  resetArrays();
}

void resetArrays() {
  distances.clear();
  distancesR.clear();
  diffDistances.clear();
  definitive.clear();
  confidences.clear();
}

void loadNewSample() {
  fullSizeSample = loadImage("sample.png");
  smallSample = new Image(loadImage("sample.png"), displayW/ratio, displayH/ratio);
}

void warpImage() {
  // warp the selected region on the input image (cam) to an output image of width x height
  out = attention.focus(cam, cam.width, cam.height);
  float thresh = map(mouseX, 0, height, 0, 1.0);
  out.filter(THRESHOLD, thresh);
  if (invert) {
    out.filter(INVERT);
  }
}

void keyPressed() {
  if (key == 'R' || key == 'r') {
    saveFrame("/Users/ishac/Documents/Processing/Stage2_Interpreting_SeeInside_auto/data/sample.jpg");
    out.save("/Users/ishac/Documents/Processing/Stage2_Interpreting_SeeInside_auto/data/sample.png");
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

int countPixels(PImage img){
  img.loadPixels();
  int numPix = 0;
  for (int i=0; i < img.pixels.length; i++){
    if (red(img.pixels[i]) == 255){
      numPix++;
    }
  }
  return numPix;
}
