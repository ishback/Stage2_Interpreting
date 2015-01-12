import java.awt.Rectangle;

class Image {
  public String filename;
  PImage pImage;
  PVector center = new PVector();
  Rectangle bb = new Rectangle();
  ArrayList<PVector> whitePix = new ArrayList<PVector>();
  
  
//  
//  PImage imgSmall;
//  PImage imgLarge;
//  PImage imgResized;
//  PImage dest;
//  float maxX = 0;
//  float minX = width;
//  float maxY = 0;
//  float minY = height;
//  float w;
//  float h;
//  int lowResWidth;
//  int lowResHeight;
//  //float ratio;
//  PVector cog; // center of gravity of the image
//  PVector centering; // stores the vector that centers with the sample
//  ArrayList<PVector> whitePix;
//  ArrayList<PVector> whitePixCentered;
  
  Image() { 
  }
  
  Image(PImage image) { 
    pImage = image;
  }
  
  Image(PImage image, int w, int h) { 
    pImage = image;
    pImage.resize(w,h);
    storeWhitePixels();
    calculateBB();
  }
  
  int getWidth() {
    return pImage.width;
  }
  
  int getHeight() {
    return pImage.height;
  }
  
  ArrayList<PVector> getWhitePixels() {
    return whitePix;
  }
  
  void storeWhitePixels() {
    for (int i=0; i < pImage.width*pImage.height; i++){
      if (red(pImage.pixels[i]) == 255){ //the pixel is white
        whitePix.add(new PVector(i%pImage.width, i/pImage.width));
      }
    }
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
  }
  
  PVector getCenter() {
    return center;
  }
  
  void display(color c) {
    tint(c);
    imageMode(CENTER);
    image(pImage, center.x, center.y);
  }
}
