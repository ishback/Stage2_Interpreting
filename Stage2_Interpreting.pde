import com.jonwohl.*;
import processing.video.*;
import gab.opencv.*;
import processing.serial.*;
import cc.arduino.*;

Arduino arduino;
int buttonPin = 4;
int potPin = 0;

Attention attention;
Capture cam;
PImage out;
PImage src, dst;
PImage temp, prevTemp;
PVector centroid, prevCentroid;
OpenCV opencv;
// A list of all the contours found by OpenCV
ArrayList<Contour> contours;

int displayW = 1280;
int displayH = 720;
int camW = 640;
int camH = 480;

PImage fullSizeSample;
Image smallSample;
//ArrayList<PImage> fullSizeModels;
//ArrayList<Image> smallModels;
//ArrayList<Image> resizedModels;
ArrayList<Image> models;
Image sample;

FloatList distances;
FloatList distancesR; //reverse order
FloatList diffDistances; //absolute value of the d-dR
FloatList definitive;

int ratio = 6;

color green = color(0, 255, 0);
color ghost = color(255, 50);
color white = color(255);

PFont f;
PFont bold;
PFont text;

int numModels;
int currentModelIndex = 0;
int closestModel = 0;
int nearest;

// these are for ratio=4;
//int confidenceMin = 5000;
//int confidenceMin = 60000;
// these are for ratio=6;
int confidenceMin = 10000;
int confidenceMax = 80000;
float confidence = 0;
float confidenceThres = 80;
float confidenceStep = 0;
float paramEasing = 0.10;
int counter = 0;
int counterMax = 60;
int counterFound = 0;
int counterFoundMax = 210;
int counterCursor = 0;
int counterCursorMax = 35;
int counterWatching = 0;
int counterWatchingMax = 10;
int counterImageChanging = 0;
int counterImageChangingMax = 10; // freq of checking new image is counterWatchingMax*counterImageChangingMax
int counterTransitioning = 0;
int alphaFading = 8; // increase to darken
int counterTransitioningWait1 = 80;
int counterTransitioningFade = 120;
int counterTransitioningWait2 = 140;
int prevNumPixels = 0;
int numPixels = 0;
int thresNumPixels = 7000;
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
boolean invert = false;
boolean cursorON = true;
boolean imageHasChanged = false;
boolean useThreshold = false;
boolean buttonDown = false;
boolean pauseProcess = true;
int dir; //0 sample against model / 1 model against sample


/////////////////////////////////////////////////////////////////////////////  SETUP
void setup() {
  size(displayW, displayH);
  background(0);

  String[] ards = Arduino.list();
  //println(ards);
  
  // for Mac
  // arduino = new Arduino(this, ards[ards.length - 1], 57600);
  
  // for Odroid
  arduino = new Arduino(this, ards[0], 57600);
  arduino.pinMode(4, Arduino.INPUT);

  // For ODroid
  cam = new Capture(this, camW, camH, "/dev/video0", 30);

  // For Mac
  //cam = new Capture(this, camW, camH);
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
  java.io.File modelFolder = new java.io.File(dataPath("models_st4"));
  String[] modelFilenamesTemp = modelFolder.list();
//  fullSizeSample = createImage(camW, camH, RGB);
  models = new ArrayList<Image>();
//  
//  fullSizeModels = new ArrayList<PImage>();
//  smallModels = new ArrayList<Image>();
//  resizedModels = new ArrayList<Image>();
  
  confidences = new ArrayList<Float>();
  for (int i = 0; i < modelFilenamesTemp.length; i++) {
    if (!modelFilenamesTemp[i].startsWith(".")) {
      String filename = "models_st4/" + modelFilenamesTemp[i];
      // we resize width of models at displayH since their ratio is 1:1.
      models.add(new Image(filename, displayH, displayH, ratio));
    }
  }
  
  
  numModels = models.size();
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
  //background(0);
  
  if (pauseProcess) {
    background(0);
    //println("process paused");
    if (cam.available()) {
      // read a new frame
      cam.read();
      warpImage();
    }
    return;
  }
  
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
        //println("IMAGE HAS CHANGED");
        counterImageChanging = 0;
      }
      if (imageHasChanged){
        if (counterImageChanging < counterImageChangingMax){
          counterImageChanging++;
          //println("counterImageChanging: " + counterImageChanging);
          background(0);
          waiting = true;
          transitioning = false;
          comparing = false;
          confidences.clear();
        } else { // image has changed and has been stable for a while -> use it as new sample
          image(out, 0, 0);
          out.save("data/sample.png");
          newImage = true;
          //println("NEW IMAGE SAVED");
          counterImageChanging = 0;
          imageHasChanged = false;
          currentModelIndex = 0;
          confidences.clear();
          closestModel = 0;
          counter = 0;
        }
      }
    }
    counterWatching = 0;
  }
 
  if (newImage) {
    reset();
    loadNewSample();
    background(0);
    noTint();
    //image(sample.pImage, 0, 0);
    sample.displayBigCenteredAt(displayW/2, displayH/2);
    newImage = false;
    transitioning = true;
    currentModelIndex = 0;
  } else if (transitioning){
    //println("counterTransitioning: " + counterTransitioning);
    if (counterTransitioning <= counterTransitioningWait1){
      counterTransitioning++;
    } else if (counterTransitioning <= counterTransitioningFade){
      fill(0, alphaFading);
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
    //readConfidenceThres();
    
      // show behind the scenes in green
    if (arduino.digitalRead(buttonPin) == Arduino.HIGH){
      buttonDown = true;
    } else {
      buttonDown = false;
    }
    //println("buttonDown: " + buttonDown);
    
    if (counter == 0) {
      background(0);
      Image curModel = models.get(currentModelIndex);
      
      //float croppedSampleToModelRatioW = sample.croppedImage.width / curModel.croppedImage.width;
      //float croppedSampleToModelRatioH = sample.croppedImage.height / curModel.croppedImage.height;

      // resize cropped model to match cropped sample
      curModel.generateResized(sample.croppedImage.width, sample.croppedImage.height);

      //  from small model to resized model, get from model
      //float resizeRatioW = curModel.getResizeRatio().x;
      //float resizeRatioH = curModel.getResizeRatio().y;
      

      // using the new width and height of the small resized MODEL, create a big resized model for display 
      //println("Displaying model " + currentModelIndex);
      tint(white);
      curModel.displayBigResizedCenteredAt(displayW/2, displayH/2);
      
      // using the new width and height of the small resized SAMPLE, create a big resized sample for display 
//      PImage bigResizedSample = loadImage(smallSample.filename);
      //println("Sample dimensions: " + sample.croppedImage.width + " x " + sample.croppedImage.height);
      tint(ghost);
      //println("display big sample at: " + displayW/2 + ", " + displayH/2);
      sample.displayBigCenteredAt(displayW/2, displayH/2);
      
      
      //curModel.displayWhitePixelsResizedCenteredAt(100, 100);
      //sample.displayWhitePixelsCroppedCenteredAt(100, 100);
      
      
      // calculate distances to sample
      calculateDist(currentModelIndex);
      confidence = map(definitive.get(currentModelIndex), confidenceMin, confidenceMax, 100, 0);
      if (confidence > 100){
        confidence = 100;
      } else if (confidence < 0){
        confidence = 2;
      }
      confidences.add(confidence);
      if (confidence > confidences.get(closestModel)){
        closestModel = currentModelIndex;
      }
      //println("confidence: " + confidence);
      //println("confidenceThres: " + confidenceThres);
      confidenceStep = 0;
      newImage = false;
      //println("currentModelIndex: " + currentModelIndex + "  numModels: " + numModels);
      counter++;
    } else if (counter < counterMax && counter != 0) {
      counter++;
    } else if (counter >= counterMax){
//      if (confidence > confidenceThres){
//        comparing = false;
//        matchFound = true;
//        counterFound = 0;
//        String[] q = splitTokens(models.get(currentModelIndex).filename, "/");
//        println(q[1]);
//        String[] t = splitTokens(q[1], ".");
//        name = new String(t[0]);
//      } else 
      if (currentModelIndex < numModels - 1) {
      counter = 0;
      currentModelIndex++;
      } else if (currentModelIndex == numModels - 1) {
      comparing = false;
      matchFound = true;
      counter = 0;
      counterFound = 0;
      counterCursor = 0;
      currentModelIndex = 0;
      }
    }
    //if (debugView && counter !=0) {
    if (buttonDown) {
      
      //showTrueView();
      //drawConfidence();
      drawBars();
//      pushMatrix();
//      translate(width - 120, height-60);
//      fill(255, 0, 255);
//      textFont(f);
//      text(confidence, 0, 0);
//      popMatrix();
    }
  } else if (matchFound){
    if (counterFound < counterFoundMax*0.5){
      //models.get(currentModelIndex).display(int(models.get(currentModelIndex).centering.x)*ratio, int(models.get(currentModelIndex).centering.y)*ratio, white);
      background(0);
      if (useThreshold && confidences.size() > 0){
        if (confidences.get(closestModel) >= confidenceThres){
          displayMatchText();
        } else {
        displayIDunno();
        }
      
      } else {
        displayMatchText();
      }
      
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
        //println("END OF FOUND");
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
      rect(width/2, height/2, 100, 100);
      rectMode(CORNER);
    } else {
      background(0);
    }
    counterCursor++;
  }
  
  //image(out, width/4, 0, width/4, height/4);
}


/////////////////////////////////////////////////////////////////////////////  FUNCTIONS


void displayMatchText(){
  String[] q = splitTokens(models.get(closestModel).filename, "/");
  String[] t = splitTokens(q[1], ".");
  name = new String(t[0]);
  fill(255);
  textAlign(CENTER, CENTER);
  textFont(text);
  text("This looks like a", width/2, height/2 - 50);
  textFont(bold);
  text(name, width/2, height/2);
}

void displayIDunno(){
  fill(255);
  textAlign(CENTER, CENTER);
  textFont(text);
  text("Sorry, I don't know what you mean.", width/2, height/2);
}

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
  confidenceStep = confidenceStep + (confidence - confidenceStep)*paramEasing;
  rect(width-30, height-40, 10, -(map(confidenceStep, 0, 100, 0, height - 80)));
}

void drawBars(){
  noStroke();
  for (int i=0; i < confidences.size(); i++){
    noTint();
    image(models.get(i).smlImage, 20, 45 + i*30, 20, 20);
    if ((i == closestModel) && useThreshold && (confidences.get(i) > confidenceThres)){
      fill(0, 255, 0);
    } else if (i == closestModel && !useThreshold){
      fill(0, 255, 0);
    } else {
      fill(255);
    }
    if (i == currentModelIndex){
      confidenceStep = confidenceStep + (confidences.get(i) - confidenceStep)*paramEasing;
      rect(50, 50 + i*30, confidenceStep, 10);
    } else {
      rect(50, 50 + i*30, confidences.get(i), 10);
    }
    
    //println("confidence " + i + "= " + confidences.get(i));
  }
  //println("currentModel: " + currentModelIndex);
}

void calculateDist(int modelNum) {
  distances.append(nn(sample.whitePix, models.get(modelNum).whitePix, modelNum, 0));
  distancesR.append(nn(models.get(modelNum).whitePix, sample.whitePix, modelNum, 1));
  //println("distance: " + distances.get(modelNum) + "  distanceR: " + distancesR.get(modelNum));
  calculateDiff(modelNum);
  calculateDefinitive(modelNum);
  //println("Diff: " + diffDistances.get(modelNum) + "  Definitive: " + definitive.get(modelNum));
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
  if (debugView){
    pushMatrix();
    textFont(f);
    translate(50, 50);
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
    if (buttonDown){
      color c;
      if (dir == 0) {
        c = color(0, 255, 0, 30);
      } else {
        c = color(255, 0, 255, 30);
      }
      
      if (dir==0){
        stroke(0, 255, 0, 120);
        
        // Display the lines over the small images
//        pushMatrix();
//        println("sample width: " + sample.croppedImage.width);
//        translate(100 - sample.croppedImage.width/2, 100 - sample.croppedImage.height/2);
//        line(s.x, s.y, closest.x, closest.y);
//        popMatrix();
        
        // Display the lines over the big images
        pushMatrix();
        translate(displayW/2 - sample.croppedImage.width * ratio / 2, displayH/2 - sample.croppedImage.height * ratio / 2);
        noFill();
        line(s.x*ratio, s.y*ratio, closest.x*ratio, closest.y*ratio);
        //line((s.x + cenS.x)*ratio, (s.y + cenS.y)*ratio, (closest.x + cenM.x)*ratio, (closest.y + cenM.y)*ratio);
        popMatrix();
      }
      
      //popMatrix();
    }
    totalDist += dist;
    
  }
  // Print the distances, one way and the other.
//  if (debugView){
//    pushMatrix();
//    if (dir == 0) {
//      translate(width - 120, height-80);
//      fill(0, 255, 0);
//    } else {
//      translate(width - 120, height-100);
//      fill(255, 0, 255);
//    } 
//    textFont(f);
//    text(totalDist, 0, 0);
//    popMatrix();
//  }
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
  sample = new Image("sample.png", displayW, displayH, ratio);
  //println("Dim sample small: " + sample.smlImage.width + ", " + sample.smlImage.height);
}

void warpImage() {
  // warp the selected region on the input image (cam) to an output image of width x height
  out = attention.focus(cam, cam.width, cam.height);
  int pin = arduino.analogRead(potPin);
  float thresh = map(pin, 0, 1023, 0, 1.3);
  //println("pot: " + pin + ", " + thresh);
  //float thresh = map(mouseX, 0, height, 0, 1.0);
  out.filter(THRESHOLD, thresh);
  if (invert) {
    out.filter(INVERT);
  }
  if (debugView) {
    image(out, camW, 0);
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
    background(0);
  } else if (key == 'P' || key == 'p') {
    pauseProcess = !pauseProcess;
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
