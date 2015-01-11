class Image {
  String filename;
  PImage imgSmall;
  PImage imgLarge;
  PImage imgResized;
  PImage dest;
  int maxX = 0;
  int minX = width;
  int maxY = 0;
  int minY = height;
  float w;
  float h;
  int lowResWidth;
  int lowResHeight;
  float ratioW = 1;
  float ratioH = 1;
  //float ratio;
  PVector cog; // center of gravity of the image
  PVector centering; // stores the vector that centers with the sample
  ArrayList<PVector> whitePix;
  ArrayList<PVector> whitePixCentered;
  
  Image() { 
  }
  
  void reset(){

    maxX = 0;
    minX = imgSmall.width;
    maxY = 0;
    minY = imgSmall.height;
  }
  
  void update() {
    
    println(filename);
    imgSmall = loadImage(filename);
    imgLarge = loadImage(filename);
    lowResWidth = int(width / ratio);
    lowResHeight = int(height / ratio);
    println("lowResWidth: " + lowResWidth);
    println("lowResHeight: " + lowResHeight);
    // keep the high res for display
    // work with a low res for performance
    imgSmall.resize(lowResWidth, lowResHeight);
    imgLarge.resize(width, height);
    println("smallW: " + imgSmall.width);
    println("smallH: " + imgSmall.height);
    imgSmall.filter(THRESHOLD);
    
    imgResized = createImage(lowResWidth, lowResHeight, RGB);
    imgResized.copy(imgSmall, 0, 0, lowResWidth, lowResHeight, 0, 0, lowResWidth, lowResHeight);
    whitePix = new ArrayList<PVector>();
    whitePixCentered = new ArrayList<PVector>();
    
    cog = new PVector(0,0);
  }
  
  // calculates features on small Image
  void calculateBB(){
    for (int i=0; i < whitePix.size(); i++){
      PVector dot = new PVector(whitePix.get(i).x, whitePix.get(i).y);
      maxX = int(max(maxX, dot.x));
      minX = int(min(minX, dot.x));
      maxY = int(max(maxY, dot.y));
      minY = int(min(minY, dot.y));
    }
  }
  
  void calculateCOG(){
    cog.set((maxX - minX)/2 + minX, (maxY - minY)/2 + minY);
    println("maxX: " + maxX);
    println("minX: " + minX);
    println("maxY: " + maxY);
    println("minY: " + minY);
    println(cog);
  }
  
  void displayFeatures(color c){
    stroke(c);
    noFill();
    rect((minX+centering.x)*ratio, (minY+centering.y)*ratio, (maxX-minX)*ratio, (maxY-minY)*ratio);
    noStroke();
    fill(c);
    ellipse((cog.x + centering.x)*ratio, (cog.y + centering.y)*ratio, 10, 10);
  }
  
  void displayFeaturesSmall(color c){
    pushMatrix();
    translate(centering.x, centering.y);
    stroke(c);
    noFill();
    rect(minX, minY, maxX-minX, maxY-minY);
    noStroke();
    fill(c);
    //ellipse(cog.x, cog.y, 10, 10);
    popMatrix();
  }
  
  void displaySmall(color c){
    tint(255, 126);
    image(imgSmall, 0, 0);
  }
  
  void display(int posX, int posY, color c){
    tint(c);
    image(imgLarge, posX, posY, imgLarge.width*ratioW, imgLarge.height*ratioH);
    
    if (debugView){
      stroke(c);
      noFill();
      //rect(posX, posY, width, height);
      ellipse((cog.x + centering.x)*ratio, (cog.y + centering.y)*ratio, 15, 15);
    }
  }
  
  void displayWhitePixCentered(){
    for (int i = 0; i < whitePixCentered.size(); i++){
      PVector p = whitePixCentered.get(i);
      //int loc = int(p.x + p.y*lowResWidth);
      //dest.pixels[loc] = color(255);
      stroke(255);
      point(p.x, p.y);
    }
  }
  
  void displayWhitePix(){
    displaySmall(255);
    for (int i = 0; i < whitePix.size(); i++){
      PVector p = whitePix.get(i);
      //int loc = int(p.x + p.y*lowResWidth);
      //dest.pixels[loc] = color(255);
      stroke(255);
      point(p.x, p.y);
    }
  }
  
  void storeWhitePixelsSmall(){
    for (int i=0; i < imgSmall.width*imgSmall.height; i++){
      if (red(imgSmall.pixels[i]) == 255){ //the pixel is white
        whitePix.add(new PVector(i%imgSmall.width, i/imgSmall.width));
      }
    }
  }
  
  void storeWhitePixelsResized(){
    whitePix.clear();
    for (int i=0; i < imgResized.width*imgResized.height; i++){
      if (red(imgResized.pixels[i]) == 255){ //the pixel is white
        whitePix.add(new PVector(i%imgResized.width, i/imgResized.width));
      }
    }
  }
  
  void calcCentering(PVector cogSample){
    centering = new PVector(cogSample.x, cogSample.y);
    centering.sub(cog);
  }
  
  void centerImage(PVector center){
    whitePixCentered.clear();
    for (int i=0; i < whitePix.size() ; i++){
      //PVector temp = whitePix.get(i); //this doesn't make a copy
      PVector temp = whitePix.get(i).get(); //this makes a copy
      temp.add(center);
      temp.sub(cog);
      
      whitePixCentered.add(temp);
    }
  }
  
  void scaleImage(int sampleMaxX, int sampleMinX, int sampleMaxY, int sampleMinY){
    imgResized.copy(imgSmall, 0, 0, lowResWidth, lowResHeight, 0, 0, lowResWidth, lowResHeight);
    ratioW = float(sampleMaxX - sampleMinX)/float(maxX - minX);
    ratioH = float(sampleMaxY - sampleMinY)/float(maxY - minY);
    println("maxX: " + maxX);
    println("minX: " + minX);
    println("maxY: " + maxY);
    println("minY: " + minY);
    println("sampleMaxX: " + sampleMaxX);
    println("sampleMinX: " + sampleMinX);
    println("sampleMaxY: " + sampleMaxY);
    println("sampleMinY: " + sampleMinY);
    println("ratioW: " + ratioW);
    println("ratioH: " + ratioH);
    imgResized.resize(int(imgSmall.width*ratioW), int(imgSmall.height*ratioH));
  }
    
  
  
}
