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
//int imageW = 256;
//int imageH = 192;
color ghost = color(0, 255, 0, 100);
color white = color(255);
PFont f;
int numModels;
int nearest;
int smallW;
int smallH;

// record a new image and recalculate nearest neighbor -- press 'r' to record
boolean newImage = false;
// show what the camera is seeing -- press 'v' to toggle
boolean camView = true;
// shows small slow res images on top left corner
boolean debugView = false;
// whether or not to invert the thresholded image -- press 'i' to toggle
boolean invert = false;
int dir; //0 sample against model / 1 model against sample

void setup() {
  size(1024/2, 768/2);

  //size(1280, 1024);
  background(0);
  smooth();
  //cam = new Capture(this, 640, 480, "Logitech Camera", 30);
  cam = new Capture(this, 640, 480);
  cam.start();
  // PImage dst = createImage(640, 480, RGB);
  // instantiate focus passing an initial input image
  attention = new Attention(this, cam);
  out = attention.focus(cam, width, height);
  f = loadFont( "Inconsolata-Regular-14.vlw" );
  textFont(f);  
  
  // load all the model images and calculate its features
  java.io.File modelFolder = new java.io.File(dataPath("models"));
  String[] modelFilenamesTemp = modelFolder.list();
  sample = new Image();
  models = new ArrayList<Image>();
  for (int i = 0; i < modelFilenamesTemp.length; i++) {
    if (!modelFilenamesTemp[i].startsWith(".")){
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
  //size(imageW * 6, imageH * 3 + 100);
  
}

void draw(){
  if (camView){
    if (cam.available()) {
      // read a new frame
      cam.read();
      // warp using library. invert if needed -- toggle with 'i'
      warpImage();
    }
  } else if (newImage){
    background(0);
    loadNewSample();
    
    // display the new sample
    sample.display(0, 0, white);
    sample.displayFeatures();
    
    displayModel(0);
    sample.displayWhitePix();
    models.get(0).centerImage(sample.cog);
    models.get(0).displayWhitePixCentered();
    resetArrays();
    recalculate(0);
    newImage = false;
  }
  if (debugView){
    models.get(0).displaySmall(white);
    sample.displaySmall(white);
  }
}

void displayModel(int modelNum){
  // center and display the model
  //models.get(0).centerImage(sample.cog); // take the model and center with the sample.
  
  PVector vToCenter = new PVector(sample.cog.x, sample.cog.y);
  vToCenter.sub(models.get(0).cog);
  models.get(0).display(0, 0, white);
  //models.get(0).display(int(vToCenter.x*models.get(0).ratioW), int(vToCenter.y*models.get(0).ratioH), white);
  fill(255);
  //ellipse(models.get(0).cog.x*models.get(0).ratio, models.get(0).cog.y*models.get(0).ratio, 10, 10);
  println("cog: " + models.get(0).cog);
  models.get(0).displayFeatures();

}

void recalculate(int modelNum){
  distances.append(nn(sample.whitePix, models.get(modelNum).whitePixCentered, modelNum+1, 0));
  distancesR.append(nn(models.get(modelNum).whitePixCentered, sample.whitePix, modelNum+1, 1));
  calculateDiff(modelNum);
  calculateDefinitive(modelNum);
  if (definitive.get(modelNum) == definitive.min()){
    nearest = modelNum; //this saves the index of the closest model.
  }
}

void calculateDiff(int pos){
  int posX = (pos+1)%(smallW);
  int posY = (pos+1)/(smallW);
  diffDistances.append(abs(distances.get(pos) - distancesR.get(pos))); 
  pushMatrix();
  translate(smallW*posX + 50, smallH*posY + 210);
  fill(255);
  text(diffDistances.get(pos), 0, 0);
  popMatrix();
}

void calculateDefinitive(int pos){
  int posX = (pos+1)%(smallW);
  int posY = (pos+1)/(smallW);
  definitive.append(distances.get(pos) + distancesR.get(pos) + diffDistances.get(pos));
  pushMatrix();
  translate(smallW*posX + 50, smallH*posY + 225);
  fill(255);
  text(definitive.get(pos), 0, 0);
  popMatrix(); 
}

float nn (ArrayList<PVector> arraySample, ArrayList<PVector> arrayModel, int pos, int dir){
  float totalDist = 0;
  PVector closest = new PVector(0,0);
  int posX = pos%(ratio);
  int posY = pos/(ratio);
  for (int i = 0 ; i < arraySample.size() ; i++) {
    float dist = 100000000; // set to large number initially. no need to store.
    PVector s = arraySample.get(i);
    for (int j = 0 ; j < arrayModel.size() ; j++) {
      PVector m = arrayModel.get(j);
      float thisDist = dist(s.x, s.y, m.x, m.y);
      
      if (thisDist < dist) {
        dist = thisDist;
        closest = new PVector(m.x, m.y);
      }
    }
    color c;
    if (dir == 0){
      c = color(0, 255, 0, 30);
    } else {
      c = color(255, 0, 255, 30);
    }
    stroke(c);
    //pushMatrix();
    //translate(imageW*posX, imageH*posY);
    //line(s.x, s.y, closest.x, closest.y);
    //popMatrix();
    totalDist += dist;
  }
  pushMatrix();
  if (dir == 0){
    translate(smallW + 50, smallH + 180);
    fill(0,255,0);
  } else {
    translate(smallW + 50, smallH + 195);
    fill(255,0,255);
  } 
  
  text(totalDist, 0, 0);
  popMatrix();
  println("totalDist: " + totalDist);
  return totalDist;
}

void resetArrays(){
  distances.clear();
  distancesR.clear();
  diffDistances.clear();
  definitive.clear();
}

void loadNewSample(){
  //sample.filename = "sample.jpg";
  sample.filename = "sample.png"; // static image for testing
  
  sample.update();
  sample.reset();
  sample.calculateFeatures();
  sample.centerImage(sample.cog);
}

void warpImage(){
  // warp the selected region on the input image (cam) to an output image of width x height
  out = attention.focus(cam, width, height);
  image(out, 0, 0);
  float thresh = map(mouseY, 0, height, 0, 1.0);
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
  } else if (key == 'V' || key == 'v') {
    camView = true; 
  } else if (key == 'D' || key == 'd') {
    debugView = true;
  }
  // do or don't invert input
  if (key == 'i' || key == 'I') {
    invert = !invert;
  }
}
