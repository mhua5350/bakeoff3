import java.util.Arrays;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Random;
import java.util.Comparator;

// Set the DPI to make your smartwatch 1 inch square. Measure it on the screen
final int DPIofYourDeviceScreen = 140; //you will need to look up the DPI or PPI of your device to make sure you get the right scale!!
//http://en.wikipedia.org/wiki/List_of_displays_by_pixel_density

//Do not change the following variables
String[] phrases; //contains all of the phrases
String[] suggestions; //contains all of the phrases
int totalTrialNum = 3 + (int)random(3); //the total number of phrases to be tested - set this low for testing. Might be ~10 for the real bakeoff!
int currTrialNum = 0; // the current trial number (indexes into trials array above)
float startTime = 0; // time starts when the first letter is entered
float finishTime = 0; // records the time of when the final trial ends
float lastTime = 0; //the timestamp of when the last trial was completed
float lettersEnteredTotal = 0; //a running total of the number of letters the user has entered (need this for final WPM computation)
float lettersExpectedTotal = 0; //a running total of the number of letters expected (correct phrases)
float errorsTotal = 0; //a running total of the number of errors (when hitting next)
String currentPhrase = ""; //the current target phrase
String currentTyped = ""; //what the user has typed so far
final float sizeOfInputArea = DPIofYourDeviceScreen*1; //aka, 1.0 inches square!
PImage watch;
PImage mouseCursor;
float cursorHeight;
float cursorWidth;

class Box
{
  float x;
  float y;
  float w;
  float h;
  
  Box(float x, float y, float w, float h) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
  }
}

class StrFreq
{
  String c;
  long f;
  
  StrFreq(String c, long f) {
    this.c = c;
    this.f = f;
  }
}

class TrieNode
{
  char c;
  long f;
  boolean endOfWord;
  HashMap<Character, TrieNode> children;

  TrieNode(char c, long f) {
    this.children = new HashMap<Character, TrieNode>();
    this.c = c;
    this.f = f;
    this.endOfWord = false;
  }
}

class Trie
{  
  TrieNode root;

  Trie() {
    root = new TrieNode('\0', 0);
  }

  void insert(String word, long f) {
    TrieNode curr = root;
    
    for (char letter : word.toCharArray()) {
      if (!curr.children.containsKey(letter)) {
        TrieNode node = new TrieNode(letter, 0);
        curr.children.put(letter, node);
      }
      curr = curr.children.get(letter);
    }
    
    curr.endOfWord = true;
    curr.f = f;
  }

  ArrayList<StrFreq> search(String prefix) 
  {
    TrieNode curr = root;
    ArrayList<StrFreq> suggestions = new ArrayList<StrFreq>();

    for (char letter : prefix.toCharArray()) {
      if (!curr.children.containsKey(letter)) {
        return suggestions;
      }
      curr = curr.children.get(letter);
    }

    getWords(prefix, curr, suggestions);
    return suggestions;
  }

  void getWords(String prefix, TrieNode node, ArrayList<StrFreq> suggestions) {
    if (node.endOfWord) {
      StrFreq sf = new StrFreq(prefix, node.f);
      suggestions.add(sf);
    }

    for (char letter : node.children.keySet()) {
      getWords(prefix + letter, node.children.get(letter), suggestions);
    }
  }
}

HashMap<String, Box> strToBox = new HashMap<String, Box>();
HashMap<Integer, Box> suggestionToBox = new HashMap<Integer, Box>();
String[] currSuggestions;
Trie trie = new Trie();

boolean prefixChanged = false;
String currPrefix = "";
int gridRows = 6; // Number of rows
int gridCols = 6; // Number of columns
int numSuggestions = 3;
float buttonWidth, buttonHeight; // Size of each grid button
float suggestionWidth;
String[] alphabetGroups = {"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "-", "<"}; // Letter groups for grid
boolean isGridVisible = true; // Flag to control grid visibility

//You can modify anything in here. This is just a basic implementation.
void setup()
{
  watch = loadImage("watchhand3smaller.png");
  phrases = loadStrings("phrases2.txt"); //load the phrase set into memory 
  Collections.shuffle(Arrays.asList(phrases), new Random()); //randomize the order of the phrases with no seed
  //Collections.shuffle(Arrays.asList(phrases), new Random(100)); //randomize the order of the phrases with seed 100; same order every time, useful for testing
 
  orientation(LANDSCAPE); //can also be PORTRAIT - sets orientation on android device
  size(800, 800); //Sets the size of the app. You should modify this to your device's native size. Many phones today are 1080 wide by 1920 tall.
  textFont(createFont("Arial", 18)); //set the font to arial 24. Creating fonts is expensive, so make difference sizes once in setup, not draw
  noStroke(); //my code doesn't use any strokes
  
  //set finger as cursor. do not change the sizing.
  noCursor();
  mouseCursor = loadImage("finger.png"); //load finger image to use as cursor
  cursorHeight = DPIofYourDeviceScreen * (400.0/250.0); //scale finger cursor proportionally with DPI
  cursorWidth = cursorHeight * 0.6; 
  
  buttonWidth = sizeOfInputArea / gridCols; // Calculate button width based on columns
  buttonHeight = sizeOfInputArea / gridRows; // Calculate button height based on rows
  
  suggestionWidth = sizeOfInputArea / numSuggestions;
  
  String[] lines = loadStrings("ngrams/count_1w.txt");

  // Process each line
  for (String line : lines) {
    String[] columns = split(line, '\t'); // Split the line by the tab character
    String word = columns[0];
    long freq = Long.parseLong(columns[1]);
    trie.insert(word, freq);
  }
  
  currSuggestions = new String[numSuggestions];
  for (int i = 0; i < numSuggestions; i++) {
    currSuggestions[i] = ""; 
  }
  
}

//You can modify anything in here. This is just a basic implementation.
void draw()
{
  background(255); //clear background
  drawWatch(); //draw watch backgroundp
  fill(100);
  rect(width/2-sizeOfInputArea/2, height/2-sizeOfInputArea/2, sizeOfInputArea, sizeOfInputArea); //input area should be 1" by 1"

  if (finishTime!=0)
  {
    fill(128);
    textAlign(CENTER);
    text("Finished", 280, 150);
    cursor(ARROW);
    return;
  }

  if (startTime==0 & !mousePressed)
  {
    fill(128);
    textAlign(CENTER);
    text("Click to start time!", 280, 150); //display this messsage until the user clicks!
  }

  if (startTime==0 & mousePressed)
  {
    nextTrial(); //start the trials!
  }

  if (startTime!=0)
  {
    //feel free to change the size and position of the target/entered phrases and next button 
    textAlign(LEFT); //align the text left
    fill(128);
    text("Phrase " + (currTrialNum+1) + " of " + totalTrialNum, 70, 50); //draw the trial count
    fill(128);
    text("Target:   " + currentPhrase, 70, 100); //draw the target string
    text("Entered:  " + currentTyped +"|", 70, 140); //draw what the user has entered thus far 

    //draw very basic next button
    fill(255, 0, 0);
    rect(600, 600, 200, 200); //draw next button
    fill(255);
    text("NEXT > ", 650, 650); //draw next label
    
    drawGrid(); // Draw the grid of letters
    drawSuggestionGrid();

  }
  
  //draw cursor with middle of the finger nail being the cursor point. do not change this.
  image(mouseCursor, mouseX+cursorWidth/2-cursorWidth/3, mouseY+cursorHeight/2-cursorHeight/5, cursorWidth, cursorHeight); //draw user cursor   
}

void drawSuggestionGrid() {
  for (int i = 0; i < numSuggestions; i++) {
    float x = width / 2 - sizeOfInputArea / 2 + i * suggestionWidth;
    float y = height / 2 - sizeOfInputArea / 2;
    fill(200);
    rect(x, y, suggestionWidth, buttonHeight);
    
    Box box = new Box(x, y, suggestionWidth, buttonHeight);
    suggestionToBox.put(i, box);
    
    // Display the group of letters
    fill(0);
    textAlign(CENTER, CENTER);
    textSize(8);
    text(currSuggestions[i], x + suggestionWidth / 2, y + buttonHeight / 2);
    textSize(16);
  }
   // Draw grid lines
  stroke(0); // Set grid line color
  strokeWeight(1); // Set line thickness
}

void drawGrid() {
  for (int i = 0; i < gridRows; i++) {
    for (int j = 0; j < gridCols; j++) {
      int index = i * gridCols + j; // Adjust index calculation for 5x6 grid
      if (index < alphabetGroups.length) {
        // Draw each box
        float x = width / 2 - sizeOfInputArea / 2 + j * buttonWidth;
        float y = height / 2 - sizeOfInputArea / 2 + (i + 1) * buttonHeight;
        fill(200);
        rect(x, y, buttonWidth, buttonHeight);
        
        Box box = new Box(x, y, buttonWidth, buttonHeight);
        strToBox.put(alphabetGroups[index], box);
        
        // Display the group of letters
        fill(0);
        textAlign(CENTER, CENTER);
        text(alphabetGroups[index], x + buttonWidth / 2, y + buttonHeight / 2);
      }
    }
  }
   // Draw grid lines
  stroke(0); // Set grid line color
  strokeWeight(1); // Set line thickness
}


//my terrible implementation you can entirely replace
boolean didMouseClick(float x, float y, float w, float h) //simple function to do hit testing
{
  return (mouseX > x && mouseX<x+w && mouseY>y && mouseY<y+h); //check to see if it is in button bounds
}

void mousePressed() {
  if (startTime == 0) return;
  for (String s : alphabetGroups) {
    Box box = strToBox.get(s);
    if (didMouseClick(box.x, box.y, box.w, box.h)) {
      if (s.equals("-")) {
        // If the clicked letter is "-", add a space to the typed string
        currentTyped += " ";
        currPrefix = "";
        prefixChanged = true;
      } else if (s.equals("<")) {
        // If the clicked letter is "<", perform a backspace
        if (currentTyped.length() > 0) {
          currentTyped = currentTyped.substring(0, currentTyped.length() - 1);
        }
        if (currPrefix.length() > 0) {
          currPrefix = currPrefix.substring(0, currPrefix.length() - 1);
          prefixChanged = true;
        }
      } else {
        // Add the selected letter group to the current typed string
        currentTyped += s;
        currPrefix += s;
        prefixChanged = true;
      }
    }
  }
  
  for (int i = 0; i < numSuggestions; i++) {
    Box box = suggestionToBox.get(i);
    if (didMouseClick(box.x, box.y, box.w, box.h)) {
      prefixChanged = true;
      currentTyped = currentTyped.substring(0, currentTyped.length() - currPrefix.length());
      currentTyped += currSuggestions[i];
      currentTyped += " ";
      currPrefix = "";
    }
  }
  
  if (prefixChanged && currPrefix.length() > 1) {
    ArrayList<StrFreq> allSuggestions = trie.search(currPrefix);
    Collections.sort(allSuggestions, new Comparator<StrFreq>() {
      public int compare(StrFreq kv1, StrFreq kv2) {
        return Long.compare(kv2.f, kv1.f);
      }
    });
    
    int totalNumSuggestions = min(allSuggestions.size(), numSuggestions); 
    for (int i = 0; i < numSuggestions; i++) {
      if (i < totalNumSuggestions) {
        currSuggestions[i] = allSuggestions.get(i).c; 
      }
      else {
        currSuggestions[i] = "";
      }
    }
  }
  
  

  // Handle the "NEXT" button click
  if (didMouseClick(600, 600, 200, 200)) {
    nextTrial(); // Move to the next trial
  }
}





void nextTrial()
{
  currPrefix = "";
  if (currTrialNum >= totalTrialNum) //check to see if experiment is done
    return; //if so, just return

  if (startTime!=0 && finishTime==0) //in the middle of trials
  {
    System.out.println("==================");
    System.out.println("Phrase " + (currTrialNum+1) + " of " + totalTrialNum); //output
    System.out.println("Target phrase: " + currentPhrase); //output
    System.out.println("Phrase length: " + currentPhrase.length()); //output
    System.out.println("User typed: " + currentTyped); //output
    System.out.println("User typed length: " + currentTyped.length()); //output
    System.out.println("Number of errors: " + computeLevenshteinDistance(currentTyped.trim(), currentPhrase.trim())); //trim whitespace and compute errors
    System.out.println("Time taken on this trial: " + (millis()-lastTime)); //output
    System.out.println("Time taken since beginning: " + (millis()-startTime)); //output
    System.out.println("==================");
    lettersExpectedTotal+=currentPhrase.trim().length();
    lettersEnteredTotal+=currentTyped.trim().length();
    errorsTotal+=computeLevenshteinDistance(currentTyped.trim(), currentPhrase.trim());
  }

  //probably shouldn't need to modify any of this output / penalty code.
  if (currTrialNum == totalTrialNum-1) //check to see if experiment just finished
  {
    finishTime = millis();
    System.out.println("==================");
    System.out.println("Trials complete!"); //output
    System.out.println("Total time taken: " + (finishTime - startTime)); //output
    System.out.println("Total letters entered: " + lettersEnteredTotal); //output
    System.out.println("Total letters expected: " + lettersExpectedTotal); //output
    System.out.println("Total errors entered: " + errorsTotal); //output

    float wpm = (lettersEnteredTotal/5.0f)/((finishTime - startTime)/60000f); //FYI - 60K is number of milliseconds in minute
    float freebieErrors = lettersExpectedTotal*.05; //no penalty if errors are under 5% of chars
    float penalty = max(errorsTotal-freebieErrors, 0) * .5f;
    
    System.out.println("Raw WPM: " + wpm); //output
    System.out.println("Freebie errors: " + freebieErrors); //output
    System.out.println("Penalty: " + penalty);
    System.out.println("WPM w/ penalty: " + (wpm-penalty)); //yes, minus, becuase higher WPM is better
    System.out.println("==================");

    currTrialNum++; //increment by one so this mesage only appears once when all trials are done
    return;
  }

  if (startTime==0) //first trial starting now
  {
    System.out.println("Trials beginning! Starting timer..."); //output we're done
    startTime = millis(); //start the timer!
  } 
  else
    currTrialNum++; //increment trial number

  lastTime = millis(); //record the time of when this trial ended
  currentTyped = ""; //clear what is currently typed preparing for next trial
  currentPhrase = phrases[currTrialNum]; // load the next phrase!
  //currentPhrase = "abc"; // uncomment this to override the test phrase (useful for debugging)
}


void drawWatch()
{
  float watchscale = DPIofYourDeviceScreen/138.0;
  pushMatrix();
  translate(width/2, height/2);
  scale(watchscale);
  imageMode(CENTER);
  image(watch, 0, 0);
  popMatrix();
}





//=========SHOULD NOT NEED TO TOUCH THIS METHOD AT ALL!==============
int computeLevenshteinDistance(String phrase1, String phrase2) //this computers error between two strings
{
  int[][] distance = new int[phrase1.length() + 1][phrase2.length() + 1];

  for (int i = 0; i <= phrase1.length(); i++)
    distance[i][0] = i;
  for (int j = 1; j <= phrase2.length(); j++)
    distance[0][j] = j;

  for (int i = 1; i <= phrase1.length(); i++)
    for (int j = 1; j <= phrase2.length(); j++)
      distance[i][j] = min(min(distance[i - 1][j] + 1, distance[i][j - 1] + 1), distance[i - 1][j - 1] + ((phrase1.charAt(i - 1) == phrase2.charAt(j - 1)) ? 0 : 1));

  return distance[phrase1.length()][phrase2.length()];
}
