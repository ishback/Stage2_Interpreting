import java.awt.Rectangle;

class Image {
  public String filename;
  int bigToSmallRatio;
  PImage pImage,smlImage,croppedImage,resizedImage;
  int origW, origH;
  PVector center = new PVector();
  Rectangle bb = new Rectangle();
  ArrayList<PVector> whitePix = new ArrayList<PVector>();
  PVector originalCenterToCroppedCenter = new PVector();
  
  Image() { 
  }
  
  Image(PImage image) { 
    pImage = image;
  }
  
  Image(String filename, int w, int h, int ratio) {
    this.filename = filename;
    bigToSmallRatio = ratio;
    pImage = loadImage(filename);
    pImage.resize(w, h);
    origW = w;
    origH = h;
    
    smlImage = loadImage(filename);
    // resize to ratio
    smlImage.resize(pImage.width/ratio,pImage.width/ratio);
    // store the white pixels so we can calculate bb and crop
    storeWhitePixels(smlImage);
    
    // calculate bb and crop pImage to this area
    calculateBB();
    cropToBB();
    // store new white pixel locations based on cropped image
    storeWhitePixels(croppedImage);
  }
  
//  Image(PImage image, int w, int h) { 
//    pImage = image;
//    // resize to given w/h
//    pImage.resize(w,h);
//    // store the white pixels so we can calculate bb and crop
//    storeWhitePixels();
//    // calculate bb and crop pImage to this area
//    calculateBB();
//    cropToBB();
//    // store new white pixel locations based on cropped image
//    storeWhitePixels();
//  }
  
  int getWidth() {
    return pImage.width;
  }
  
  int getHeight() {
    return pImage.height;
  }
  
  ArrayList<PVector> getWhitePixels() {
    return whitePix;
  }
  
  void storeWhitePixels(PImage img) {
    for (int i=0; i < img.width*img.height; i++){
      if (red(img.pixels[i]) == 255){ //the pixel is white
        whitePix.add(new PVector(i%img.width, i/img.width));
      }
    }
  }
  
  // whenever we resize the Image, we need to restore the white pixels.
//  void resize(int w, int h) {
//    pImage = pImage.resize(w, h);
//    storeWhitePixels();
//  }
  
  void cropToBB() {
    croppedImage = smlImage.get(bb.x, bb.y, bb.width, bb.height);
  }
  
  // calculates features on small Image
  void calculateBB(){
    float maxX = 0;
    float minX = width;
    float maxY = 0;
    float minY = height;
    for (int i=0; i < whitePix.size(); i++){
      PVector dot = new PVector(whitePix.get(i).x, whitePix.get(i).y);
      maxX = max(maxX, dot.x);
      minX = min(minX, dot.x);
      maxY = max(maxY, dot.y);
      minY = min(minY, dot.y);
    }
    bb.setBounds(int(minX),int(minY),int(maxX-minX),int(maxY-minY));
    center.x = (float)bb.getCenterX();
    center.y = (float)bb.getCenterY();
    
    // the vector from the original image center to the cropped center
    originalCenterToCroppedCenter.x = smlImage.width/2 - center.x;
    originalCenterToCroppedCenter.y = smlImage.height/2 - center.y;
  }
  
  PVector getCenter() {
    return center;
  }
  
  PVector getResizeRatio() {
    PVector resizeRatio = new PVector();
    resizeRatio.x = resizedImage.width / croppedImage.width;
    resizeRatio.y = resizedImage.height / croppedImage.height;
    return resizeRatio;
  }
  
  void generateResized(int w, int h) {
    resizedImage = croppedImage.get(0, 0, croppedImage.width, croppedImage.height);
    resizedImage.resize(w, h);
    storeWhitePixels(resizedImage);
  }
  
  void display(int x, int y, color c) {
    tint(c);
    imageMode(CENTER);
    image(smlImage, center.x, center.y);
  }
  
  void displaySmallCenteredAt(color c) {
    tint(c);
    imageMode(CENTER);
    image(smlImage, center.x, center.y);
  }
  
  void displayCroppedCenteredAt(int x, int y) {
    imageMode(CENTER);
    image(croppedImage, x, y);
  }
  
  void displayBigCenteredAt(int x, int y) {
    imageMode(CENTER);
    PVector centerShift = new PVector();
    centerShift.set(originalCenterToCroppedCenter);
    centerShift.mult(ratio);
    image(pImage, x+centerShift.x, y+centerShift.y);
  }
  
  void displayBigResizedCenteredAt(int x, int y) {
    PImage bigResized = pImage.get(0, 0, origW, origH);
    println("resize ratio: " + getResizeRatio());
    bigResized.resize(int(origW*getResizeRatio().x), int(origH*getResizeRatio().y));
    imageMode(CENTER);
    PVector centerShift = new PVector();
    centerShift.set(originalCenterToCroppedCenter);
    centerShift.mult(ratio);
    centerShift.x = centerShift.x * getResizeRatio().x;
    centerShift.y = centerShift.y * getResizeRatio().y;
    image(bigResized, x+centerShift.x, y+centerShift.y);
  }
}
