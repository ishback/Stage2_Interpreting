class Image {
  String filename;
  PImage imgSmall;
  PImage imgLarge;
  PImage scaled;
  PImage dest;
  float maxX = 0;
  float minX = width;
  float maxY = 0;
  float minY = height;
  float w;
  float h;
  int lowResWidth;
  int lowResHeight;
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
    whitePix = new ArrayList<PVector>();
    whitePixCentered = new ArrayList<PVector>();
    storeWhitePixels();
    cog = new PVector(0,0);
  }
  
  // calculates features on small Image
  void calculateFeatures(){
    for (int i=0; i < whitePix.size(); i++){
      PVector dot = new PVector(whitePix.get(i).x, whitePix.get(i).y);
      maxX = max(maxX, dot.x);
      minX = min(minX, dot.x);
      maxY = max(maxY, dot.y);
      minY = min(minY, dot.y);
    }
    
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
    println("cog: " + cog + "  cog.x*ratio: " + cog.x*ratio);
  }
  
  void displayFeaturesSmall(color c){
    pushMatrix();
    translate(centering.x, centering.y);
    stroke(c);
    noFill();
    println("maxX: " + maxX);
    rect(minX, minY, maxX-minX, maxY-minY);
    noStroke();
    fill(c);
    ellipse(cog.x, cog.y, 10, 10);
    popMatrix();
  }
  
  void displaySmall(color c){
    tint(255, 126);
    image(imgSmall, 0, 0);
    rect(0, 0, 10, 10);
  }
  
  void display(int posX, int posY, color c){
    //int posX = pos%(width/imageW);
    //int posY = pos/(width/imageW);
    //pushMatrix();
    //translate(imageW*posX, imageH*posY);
    //dest = createImage(lowResWidth, lowResHeight, ARGB);
    //dest.loadPixels();
    // this is really expensive, selecting pixels instead of image.display
    // is there another way to display just the white pixels with alpha?
    
    
    /*
    dest.updatePixels();
    dest.resize(width, height);
    image(dest, 0, 0);
*/
    tint(c);
    image(imgLarge, posX, posY);
    stroke(c);
    noFill();
    rect(posX, posY, width, height);
    ellipse((cog.x + centering.x)*ratio, (cog.y + centering.y)*ratio, 15, 15);

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
  
  void storeWhitePixels(){
    for (int i=0; i < imgSmall.width*imgSmall.height; i++){
      if (red(imgSmall.pixels[i]) == 255){ //the pixel is white
        whitePix.add(new PVector(i%imgSmall.width, i/imgSmall.width));
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
}
