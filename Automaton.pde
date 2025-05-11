// Grid parameters //<>//
int cols;                   // Number of columns in grid
int rows;                   // Number of rows in grid
float cellSize = 6;         // Size of each cell in pixels
float[][] cellValues;       // Current cell values (0-1 range)
float[][] nextCellValues;   // Next generation cell values
boolean[][] isWater;        // Tracks which cells are water vs terrain
float[][] terrain;          // Terrain height values
boolean terrainMode = false;  // Toggle for terrain building mode
boolean lowerTerrainMode = false; // Toggle for terrain lowering
boolean showInfo = true;  // Toggle for info display

// Wave parameters
float propagationRate = 1.0;  // How much of a cell's value is propagated
float upwardBias = 0.3;       // Bias towards upward propagation (vs leftward)
float newWaveProb = 0.001;    // Probability of new wave formation per cell
float newWaveValue = 0.8;     // Value for new wave cells
float waveDecay = 0.01;       // How much waves decay each frame
float waveRadius = 10 + random(-2, 4);
float[][] waveAge;
float maxWaveAge = 200;    // Maximum age before complete dissipation
float expansionRate = 1.2; // How quickly clouds expand (higher = faster)
float edgeDecayRate = 0.03; // Additional decay at the edges of clouds
float centralDensity = 0.9; // Density at the center of newly formed clouds
boolean useCloudMode = true; // Toggle between regular waves and cloud mode

// Wind parameters
float windDirX = 1.0;  // X component of wind direction
float windDirY = 0.0;  // Y component of wind direction
float windSpeed = 0.60; // Wind speed multiplier
boolean windDirectionMode = false;

// Visual parameters
color[] waterColors;        // Array of water colors for gradient
color[] terrainColors;      // Array of terrain colors (sand to mountains)
int numWaterColors = 7;     // Number of colors in water gradient
int numTerrainColors = 5;   // Number of colors in terrain gradient
boolean showGrid = false;   // Option to show grid lines

// Terrain creation
float terrainBrushSize = 15;    // Size of terrain brush
float terrainStrength = 5;      // Height added per click
float terrainAmplitude = 20;    // Max height of terrain
PVector lastMousePos = new PVector(-1, -1); // Track last mouse position

// Noise parameters
float noiseScale = 0.02;    // Scale of noise for wave initialization
int noiseSeed;              // Random seed for noise

// Performance tracking
int frameCounter = 0;       // Counter for animation timing
int lastFrameRate = 0;      // Track framerate for display

void setup() {
  size(900, 600);
  colorMode(RGB, 255, 255, 255, 100);
  
  // Set a new random seed each time
  noiseSeed = int(random(10000));
  noiseSeed(noiseSeed);
  
  // Calculate grid dimensions
  cols = width / int(cellSize) + 1;
  rows = height / int(cellSize) + 1;
  
  // Initialize arrays
  cellValues = new float[cols][rows];
  nextCellValues = new float[cols][rows];
  isWater = new boolean[cols][rows];
  terrain = new float[cols][rows];
  waveAge = new float[cols][rows];
  
  // Create color palettes
  waterColors = createWaterColors();
  terrainColors = createTerrainColors();
  
  // Generate random terrain
  generateRandomTerrain();
  
  // Initialize wave field
  initializeGrid();
  
  // Update water/terrain status
  updateWaterStatus();
}

void draw() {
  background(10, 20, 40);  // Deep blue-black background
  frameCounter++;
  
  // Update the CA simulation
  updateCA();
  
  // Draw the terrain and waves
  drawTerrain();
  drawWaves();
  
  // Handle continuous terrain drawing if mouse is pressed
  if (terrainMode && mousePressed && mouseX >= 0 && mouseX < width && mouseY >= 0 && mouseY < height) {
    // Check if mouse has moved since last frame
    if (lastMousePos.x != mouseX || lastMousePos.y != mouseY) {
      if (lowerTerrainMode) {
        lowerTerrainAt(mouseX, mouseY, terrainStrength);
      } else {
        addTerrainAt(mouseX, mouseY, terrainStrength);
      }
      // Update last mouse position
      lastMousePos.set(mouseX, mouseY);
      
      // Update water status after terrain modification
      updateWaterStatus();
    }
  } else {
    // Reset last position when not drawing
    lastMousePos.set(-1, -1);
  }
  
  // Add atmospheric effects
  drawAtmosphericEffects();
  
  // Display controls and brush if in terrain mode
  displayInfo();
  
    // Draw brush indicator for both terrain and wave modes
  if (mouseX >= 0 && mouseX < width && mouseY >= 0 && mouseY < height) {
    noFill();
    if (terrainMode) {
      // Terrain brush
      stroke(lowerTerrainMode ? color(255, 100, 100, 40) : color(255, 200, 100, 40));
      strokeWeight(2);
      ellipse(mouseX, mouseY, terrainBrushSize * 2, terrainBrushSize * 2);
    } else {
      // Wave brush
      stroke(200, 220, 255, 40);
      strokeWeight(2);
      ellipse(mouseX, mouseY, waveRadius * 2, waveRadius * 2);
    }
  }
  
  // Update framerate counter every 10 frames
  if (frameCounter % 10 == 0) {
    lastFrameRate = int(frameRate);
  }
}

void updateCA() {
  // Initialize next state
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      nextCellValues[i][j] = cellValues[i][j];
    }
  }

  float timeOffset = frameCount * 0.01;
  
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      if (isWater[i][j]) {
        // Age clouds
        if (cellValues[i][j] > 0.1) {
          waveAge[i][j] += 1;
        } else {
          waveAge[i][j] = 0;
        }
        
        // Calculate age-based decay
        float ageDecay = map(waveAge[i][j], 0, maxWaveAge, waveDecay, waveDecay * 3);
        nextCellValues[i][j] -= ageDecay;
        
        if (cellValues[i][j] > 0.1) {
          // Calculate propagation based on age
          float ageFactor = constrain(1.0 - (waveAge[i][j] / maxWaveAge), 0.1, 1.0);
          float propagationAmount = cellValues[i][j] * propagationRate * expansionRate * ageFactor;
          
          nextCellValues[i][j] -= propagationAmount;

          // Calculate wind-influenced propagation
          float[] dirStrengths = new float[4]; // Right, Left, Down, Up
          
          // Base directional factors with wind influence
          dirStrengths[0] = 0.25 + (windDirX > 0 ? windDirX * 0.5 : 0);
          dirStrengths[1] = 0.25 + (windDirX < 0 ? -windDirX * 0.5 : 0);
          dirStrengths[2] = 0.25 + (windDirY > 0 ? windDirY * 0.5 : 0);
          dirStrengths[3] = 0.25 + (windDirY < 0 ? -windDirY * 0.5 : 0);
          
          // Add circular patterns with wind bias
          float waveAngle = noise(i * 0.1, j * 0.1, timeOffset) * TWO_PI;
          float directionBias = 0.8;
          
          dirStrengths[0] += cos(waveAngle) * directionBias * (cos(waveAngle) > 0 ? 1 : 0);
          dirStrengths[1] += cos(waveAngle) * directionBias * (cos(waveAngle) < 0 ? 1 : 0);
          dirStrengths[2] += sin(waveAngle) * directionBias * (sin(waveAngle) > 0 ? 1 : 0);
          dirStrengths[3] += sin(waveAngle) * directionBias * (sin(waveAngle) < 0 ? 1 : 0);
          
          // Normalize directions
          float totalStrength = dirStrengths[0] + dirStrengths[1] + dirStrengths[2] + dirStrengths[3];
          for (int d = 0; d < 4; d++) {
            dirStrengths[d] /= totalStrength;
          }

          // Spread energy
          spreadEnergy(i, j, propagationAmount, dirStrengths, ageFactor);
          
          // Add random turbulence
          if (random(1) < 0.1 * ageFactor) {
            int turbDir = int(random(4));
            int ni = i + (turbDir == 0 ? 1 : (turbDir == 1 ? -1 : 0));
            int nj = j + (turbDir == 2 ? 1 : (turbDir == 3 ? -1 : 0));
            
            if (ni >= 0 && ni < cols && nj >= 0 && nj < rows && isWater[ni][nj]) {
              nextCellValues[ni][nj] += random(0.05, 0.15) * ageFactor;
            }
          }
        }

        // Generate random waves in still water
        if (cellValues[i][j] < 0.1 && random(1) < 0.0005) {
          float newWaveStrength = random(0.3, 0.6);
          nextCellValues[i][j] = newWaveStrength;
          waveAge[i][j] = 0;
        }
      }
    }
  }

  // Apply cloud smoothing
  cloudSmoothing();

  // Update current state
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      cellValues[i][j] = constrain(nextCellValues[i][j], 0, 1);
    }
  }
}

void spreadEnergy(int i, int j, float propagationAmount, float[] dirStrengths, float ageFactor) {
  // Enhancement for cloud mode - variable propagation distance
  int spreadDistance = useCloudMode ? 
    constrain(int(2 * ageFactor), 1, 2) : 1;
  
  float energyDecay = useCloudMode ? 0.7 : 0.5; // How quickly energy decays with distance
  
  // Spread to nearby cells
  for (int dist = 1; dist <= spreadDistance; dist++) {
    float distFactor = pow(energyDecay, dist-1);
    
    // Right
    if (i + dist < cols && isWater[i + dist][j]) {
      float energy = propagationAmount * dirStrengths[0] * distFactor * windSpeed;
      nextCellValues[i + dist][j] += energy;
      
      // For clouds, propagate some energy diagonally too
      if (useCloudMode && j + 1 < rows && isWater[i + dist][j + 1]) {
        nextCellValues[i + dist][j + 1] += energy * 0.3;
      }
      if (useCloudMode && j - 1 >= 0 && isWater[i + dist][j - 1]) {
        nextCellValues[i + dist][j - 1] += energy * 0.3;
      }
    }
    
    // Left
    if (i - dist >= 0 && isWater[i - dist][j]) {
      float energy = propagationAmount * dirStrengths[1] * distFactor * windSpeed;
      nextCellValues[i - dist][j] += energy;
      
      // Diagonal spreading for clouds
      if (useCloudMode && j + 1 < rows && isWater[i - dist][j + 1]) {
        nextCellValues[i - dist][j + 1] += energy * 0.3;
      }
      if (useCloudMode && j - 1 >= 0 && isWater[i - dist][j - 1]) {
        nextCellValues[i - dist][j - 1] += energy * 0.3;
      }
    }
    
    // Down
    if (j + dist < rows && isWater[i][j + dist]) {
      float energy = propagationAmount * dirStrengths[2] * distFactor * windSpeed;
      nextCellValues[i][j + dist] += energy;
      
      // Diagonal spreading for clouds
      if (useCloudMode && i + 1 < cols && isWater[i + 1][j + dist]) {
        nextCellValues[i + 1][j + dist] += energy * 0.3;
      }
      if (useCloudMode && i - 1 >= 0 && isWater[i - 1][j + dist]) {
        nextCellValues[i - 1][j + dist] += energy * 0.3;
      }
    }
    
    // Up
    if (j - dist >= 0 && isWater[i][j - dist]) {
      float energy = propagationAmount * dirStrengths[3] * distFactor * windSpeed;
      nextCellValues[i][j - dist] += energy;
      
      // Diagonal spreading for clouds
      if (useCloudMode && i + 1 < cols && isWater[i + 1][j - dist]) {
        nextCellValues[i + 1][j - dist] += energy * 0.3;
      }
      if (useCloudMode && i - 1 >= 0 && isWater[i - 1][j - dist]) {
        nextCellValues[i - 1][j - dist] += energy * 0.3;
      }
    }
  }
  
  // Add direct diagonal propagation
  float diagStrength = propagationAmount * (useCloudMode ? 0.5 : 0.3) * windSpeed;
  
  // Bottom-right
  if (i + 1 < cols && j + 1 < rows && isWater[i + 1][j + 1]) {
    nextCellValues[i + 1][j + 1] += diagStrength * (dirStrengths[0] + dirStrengths[2]) * 0.5;
  }
  // Bottom-left
  if (i - 1 >= 0 && j + 1 < rows && isWater[i - 1][j + 1]) {
    nextCellValues[i - 1][j + 1] += diagStrength * (dirStrengths[1] + dirStrengths[2]) * 0.5;
  }
  // Top-right
  if (i + 1 < cols && j - 1 >= 0 && isWater[i + 1][j - 1]) {
    nextCellValues[i + 1][j - 1] += diagStrength * (dirStrengths[0] + dirStrengths[3]) * 0.5;
  }
  // Top-left
  if (i - 1 >= 0 && j - 1 >= 0 && isWater[i - 1][j - 1]) {
    nextCellValues[i - 1][j - 1] += diagStrength * (dirStrengths[1] + dirStrengths[3]) * 0.5;
  }
}

// 5. Add this new cloud-specific smoothing function
void cloudSmoothing() {
  // Create a temporary array for the smoothing pass
  float[][] smoothed = new float[cols][rows];
  
  // Copy current values
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      smoothed[i][j] = nextCellValues[i][j];
    }
  }
  
  // Apply uneven cloud-like smoothing
  for (int i = 1; i < cols-1; i++) {
    for (int j = 1; j < rows-1; j++) {
      if (isWater[i][j] && nextCellValues[i][j] > 0.05) {
        // Count active neighbors to identify cloud edges
        int activeNeighbors = 0;
        for (int di = -1; di <= 1; di++) {
          for (int dj = -1; dj <= 1; dj++) {
            if (di == 0 && dj == 0) continue;
            
            int ni = i + di;
            int nj = j + dj;
            
            if (ni >= 0 && ni < cols && nj >= 0 && nj < rows && 
                isWater[ni][nj] && nextCellValues[ni][nj] > 0.1) {
              activeNeighbors++;
            }
          }
        }
        
        // Identify edge cells (fewer active neighbors)
        boolean isEdge = activeNeighbors < 4;
        
        // Apply stronger decay at edges to create wispy edges
        if (isEdge) {
          smoothed[i][j] -= edgeDecayRate;
        }
        
        // Calculate weighted average with noise for varied cloud texture
        float sum = nextCellValues[i][j] * 0.4; // Self weight
        float weight = 0.4;
        
        for (int di = -1; di <= 1; di++) {
          for (int dj = -1; dj <= 1; dj++) {
            if (di == 0 && dj == 0) continue;
            
            int ni = i + di;
            int nj = j + dj;
            
            if (ni >= 0 && ni < cols && nj >= 0 && nj < rows && isWater[ni][nj]) {
              // Add some irregularity to the smoothing weights
              float noiseWeight = noise(ni * 0.2, nj * 0.2, frameCount * 0.01);
              float neighborWeight = 0.05 + noiseWeight * 0.03;
              
              sum += nextCellValues[ni][nj] * neighborWeight;
              weight += neighborWeight;
            }
          }
        }
        
        // Apply the smoothed value with some noise for cloud texture
        if (weight > 0) {
          float textureNoise = noise(i * 0.3, j * 0.3, frameCount * 0.02) * 0.1 - 0.05;
          smoothed[i][j] = (sum / weight) + textureNoise;
        }
      }
    }
  }
  
  // Copy smoothed values back to nextCellValues
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      nextCellValues[i][j] = smoothed[i][j];
    }
  }
}

void createCloud(float x, float y) {
  int centerI = int(x / cellSize);
  int centerJ = int(y / cellSize);
  
  float cloudRadius = waveRadius * 1.5 + random(-3, 5);
  
  // Create cloud with dense center that fades outward
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      if (isWater[i][j]) {
        float dx = i - centerI;
        float dy = j - centerJ;
        
        // Add distortion for more natural cloud shape
        float distortionScale = 0.1;
        float distortion = noise(i * distortionScale, j * distortionScale, frameCount * 0.01) * 6 - 3;
        dx += distortion;
        dy += distortion;
        
        float distance = sqrt(dx*dx + dy*dy);
        
        if (distance < cloudRadius) {
          // Cloud falloff - denser in middle, wispy at edges
          float t = distance / cloudRadius;
          float falloff = pow(1 - t, 1.8);
          
          // Add noise for texture
          float noiseVal = noise(i * 0.15, j * 0.15, frameCount * 0.01);
          float cloudStrength = falloff * (0.8 + noiseVal * 0.4);
          
          // Apply wind influence
          float windInfluence = 1.0 + windSpeed * 0.2;
          
          // Reset age for new cloud cells
          waveAge[i][j] = 0;
          
          // Apply the cloud
          cellValues[i][j] = min(cellValues[i][j] + cloudStrength * windInfluence, 1.0);
        }
      }
    }
  }
  
  // Add wispy tendrils in wind direction
  float tendrilDirX = windDirX * 0.8 + random(-0.2, 0.2);
  float tendrilDirY = windDirY * 0.8 + random(-0.2, 0.2);
  
  // Normalize direction
  float dirMag = sqrt(tendrilDirX*tendrilDirX + tendrilDirY*tendrilDirY);
  if (dirMag > 0) {
    tendrilDirX /= dirMag;
    tendrilDirY /= dirMag;
  }
  
  // Create 2-4 tendrils
  int numTendrils = int(random(2, 5));
  for (int t = 0; t < numTendrils; t++) {
    float tendrilLength = cloudRadius * random(0.6, 1.5);
    float tendrilWidth = cloudRadius * random(0.1, 0.3);
    
    // Angle variation for each tendril
    float angleVar = random(-PI/6, PI/6);
    float tDirX = tendrilDirX * cos(angleVar) - tendrilDirY * sin(angleVar);
    float tDirY = tendrilDirX * sin(angleVar) + tendrilDirY * cos(angleVar);
    
    // Start tendril from edge of main cloud
    float startDist = cloudRadius * 0.5;
    int tendrilStartI = centerI + int(tDirX * startDist);
    int tendrilStartJ = centerJ + int(tDirY * startDist);
    
    // Create tendril
    for (float dist = 0; dist < tendrilLength; dist += 0.5) {
      float waviness = sin(dist * 0.2) * tendrilWidth * 0.3;
      float perpX = -tDirY;
      float perpY = tDirX;
      
      int ti = tendrilStartI + int(tDirX * dist + perpX * waviness);
      int tj = tendrilStartJ + int(tDirY * dist + perpY * waviness);
      
      // Draw cloud puff
      for (int i = ti - int(tendrilWidth); i <= ti + int(tendrilWidth); i++) {
        for (int j = tj - int(tendrilWidth); j <= tj + int(tendrilWidth); j++) {
          if (i >= 0 && i < cols && j >= 0 && j < rows && isWater[i][j]) {
            float dx = i - ti;
            float dy = j - tj;
            float puffDist = sqrt(dx*dx + dy*dy);
            
            if (puffDist < tendrilWidth) {
              float densityFalloff = map(dist, 0, tendrilLength, 0.7, 0.1);
              float puffFalloff = 1 - (puffDist / tendrilWidth);
              float puffStrength = densityFalloff * puffFalloff * random(0.5, 0.8);
              
              cellValues[i][j] = max(cellValues[i][j], puffStrength);
              waveAge[i][j] = random(0, maxWaveAge * 0.3);
            }
          }
        }
      }
    }
  }
}

void initializeGrid() {
  // Initialize the grid with simplex noise
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      // Create a smooth noise pattern
      cellValues[i][j] = noise(i * noiseScale, j * noiseScale, frameCounter * 0.01);
      nextCellValues[i][j] = cellValues[i][j];
    }
  }
}

void updateWaterStatus() {
  // Determine which cells are water vs terrain
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      isWater[i][j] = !isTerrainVisible(i, j);
    }
  }
}

void drawWaves() {
  // Draw each water cell
  for (int i = 0; i < cols-1; i++) {
    for (int j = 0; j < rows-1; j++) {
      if (isWater[i][j]) {
        float x = i * cellSize;
        float y = j * cellSize;
        
        // Get color based on cell value
        color cellColor = getWaterColor(cellValues[i][j]);
        
        // Check if near shoreline for wave crashing effect
        boolean nearShore = isNearShore(i, j);
        if (nearShore) {
          float foamIntensity = map(cellValues[i][j], 0, 1, 0.2, 0.8);
          cellColor = lerpColor(cellColor, color(220, 230, 255), foamIntensity);
        }
        
        // Draw water cell
        noStroke();
        fill(cellColor);
        rect(x, y, cellSize, cellSize);
      }
    }
  }
  
  // Draw grid separately to ensure consistent lines
  if (showGrid) {
    stroke(255, 40);
    strokeWeight(1);
    
    // Draw vertical lines
    for (int i = 0; i <= cols; i++) {
      float x = i * cellSize;
      line(x, 0, x, height);
    }
    
    // Draw horizontal lines
    for (int j = 0; j <= rows; j++) {
      float y = j * cellSize;
      line(0, y, width, y);
    }
  }
}

void drawTerrain() {
  // Draw terrain cells
  for (int i = 0; i < cols-1; i++) {
    for (int j = 0; j < rows-1; j++) {
      if (isTerrainVisible(i, j)) {
        float x = i * cellSize;
        float y = j * cellSize;
        
        // Get terrain height and calculate appropriate color
        float terrainHeight = terrain[i][j];
        color terrainColor = getTerrainColor(terrainHeight);
        
        noStroke();
        fill(terrainColor);
        rect(x, y, cellSize, cellSize);
      }
    }
  }
}

void generateRandomTerrain() {
  float baseNoiseScale = 0.008; // Increased scale for smaller features
  int numIslands = int(random(3, 6)); // Generate 3-5 islands
  
  // Clear terrain
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      terrain[i][j] = 0;
    }
  }

  // Generate separate islands
  for (int island = 0; island < numIslands; island++) {
    // Random center point for each island
    float centerX = random(0.2, 0.8) * cols;
    float centerY = random(0.2, 0.8) * rows;
    float islandSize = random(10, 25); // Controls island size
    float rotation = random(TWO_PI); // Random rotation for variety
    
    // Add island noise
    for (int i = 0; i < cols; i++) {
      for (int j = 0; j < rows; j++) {
        // Distance from island center
        float dx = i - centerX;
        float dy = j - centerY;
        
        // Rotate point for varied island shapes
        float rotatedX = dx * cos(rotation) - dy * sin(rotation);
        float rotatedY = dx * sin(rotation) + dy * cos(rotation);
        
        // Calculate distance to center
        float distanceToCenter = sqrt(rotatedX*rotatedX + rotatedY*rotatedY);
        
        if (distanceToCenter < islandSize) {
          // Create island shape with noise
          float nx = i * baseNoiseScale;
          float ny = j * baseNoiseScale;
          
          // Multi-layered noise for natural coastlines
          float islandNoise = noise(nx + island * 100, ny, 0.5) * 0.6 +
                             noise(nx * 2 + island * 100, ny * 2, 1.0) * 0.3 +
                             noise(nx * 4 + island * 100, ny * 4, 2.0) * 0.1;
          
          // Create radial falloff for island shape
          float falloff = 1 - (distanceToCenter / islandSize);
          falloff = pow(falloff, 1.5); // Adjust power for sharper/softer edges
          
          // Combine noise with falloff
          if (falloff > 0 && islandNoise > 0.4) {
            float heightValue = falloff * islandNoise * terrainAmplitude;
            // Only set if higher than existing terrain
            terrain[i][j] = max(terrain[i][j], heightValue);
          }
        }
      }
    }
  }

  // Add some smaller island features
  addSmallIslands(int(random(3, 6)));
  
  addCoastalFeatures();
  addMountainRanges();
  smoothShoreLines();
  addBeaches();
}

void addSmallIslands(int numSmallIslands) {
  for (int i = 0; i < numSmallIslands; i++) {
    float centerX = random(0.1, 0.9) * cols;
    float centerY = random(0.1, 0.9) * rows;
    float size = random(5, 15);
    
    for (int x = -int(size); x <= int(size); x++) {
      for (int y = -int(size); y <= int(size); y++) {
        int px = int(centerX + x);
        int py = int(centerY + y);
        
        if (px >= 0 && px < cols && py >= 0 && py < rows) {
          float dist = sqrt(x*x + y*y);
          if (dist < size) {
            float falloff = pow(1 - (dist / size), 2);
            float noiseVal = noise(px * 0.1, py * 0.1, i * 10) * falloff;
            if (noiseVal > 0.3) {
              terrain[px][py] = max(terrain[px][py], 
                                  noiseVal * terrainAmplitude * 0.7);
            }
          }
        }
      }
    }
  }
}

void addMountainRanges() {
  float mountainNoiseScale = 0.03;
  float ridgeNoiseScale = 0.06;
  
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      if (terrain[i][j] > 0) {
        // Create more distributed mountain ridges
        float ridgeNoise = noise(i * ridgeNoiseScale, j * ridgeNoiseScale);
        float mountainNoise = noise(i * mountainNoiseScale, j * mountainNoiseScale);
        float distributionNoise = noise(i * 0.02, j * 0.02);
        
        // More natural distribution
        if (ridgeNoise > 0.5 && mountainNoise > 0.45 && distributionNoise > 0.4) {
          float mountainHeight = pow(mountainNoise, 1.5) * terrainAmplitude * 1.2;
          terrain[i][j] = max(terrain[i][j], mountainHeight);
          
          // Add varied rocky texture
          terrain[i][j] += noise(i * 0.3, j * 0.3) * 1.5;
        }
      }
    }
  }
}

void addBeaches() {
  float[][] tempTerrain = new float[cols][rows];
  arrayCopy(terrain, tempTerrain);
  
  for (int i = 1; i < cols-1; i++) {
    for (int j = 1; j < rows-1; j++) {
      if (terrain[i][j] > 0 && isNearWater(i, j)) {
        float distToWater = getDistanceToWater(i, j);
        float beachWidth = 3 + noise(i * 0.1, j * 0.1) * 2;
        
        if (distToWater < beachWidth) {
          // Create gradual beach slope
          float beachGradient = map(distToWater, 0, beachWidth, 0.2, 1.0);
          float originalHeight = terrain[i][j];
          tempTerrain[i][j] = originalHeight * beachGradient;
          
          // Add beach texture
          float sandRipples = noise(i * 0.3, j * 0.3, frameCount * 0.01) * 0.5;
          tempTerrain[i][j] += sandRipples;
        }
      }
    }
  }
  
  terrain = tempTerrain;
}

void addCoastalFeatures() {
  float coastalNoiseScale = 0.03;
  
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      if (terrain[i][j] > 0) {
        // Increase height more dramatically away from shore
        float distanceFromShore = getDistanceToWater(i, j);
        float heightIncrease = map(distanceFromShore, 0, 10, 0, 5);
        
        // Add more height to central areas
        if (!isNearWater(i, j)) {
          terrain[i][j] += heightIncrease;
          
          // Add vegetation noise
          float vegNoise = noise(i * 0.05, j * 0.05);
          if (vegNoise > 0.5) {
            terrain[i][j] += vegNoise * 2;
          }
        }
        
        // Keep shorelines gradual
        if (isNearWater(i, j)) {
          float coastalNoise = noise(i * coastalNoiseScale, j * coastalNoiseScale);
          terrain[i][j] = min(terrain[i][j], 3 + coastalNoise * 2);
        }
      }
    }
  }
}

float getDistanceToWater(int x, int y) {
    float minDist = 999999;
    int searchRadius = 5; // Adjust this value to change beach width calculation
    
    // Search nearby cells for water
    for (int i = -searchRadius; i <= searchRadius; i++) {
        for (int j = -searchRadius; j <= searchRadius; j++) {
            int ni = x + i;
            int nj = y + j;
            
            if (ni >= 0 && ni < cols && nj >= 0 && nj < rows) {
                if (terrain[ni][nj] <= 0) { // If water found
                    float dist = dist(x, y, ni, nj);
                    minDist = min(minDist, dist);
                }
            }
        }
    }
    
    return minDist;
}

boolean isNearWater(int x, int y) {
  int radius = 2;
  for (int i = -radius; i <= radius; i++) {
    for (int j = -radius; j <= radius; j++) {
      int ni = x + i;
      int nj = y + j;
      if (ni >= 0 && ni < cols && nj >= 0 && nj < rows) {
        if (terrain[ni][nj] <= 0) return true;
      }
    }
  }
  return false;
}

void smoothShoreLines() {
  // Create a temporary copy of the terrain
  float[][] tempTerrain = new float[cols][rows];
  
  // Copy terrain values
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      tempTerrain[i][j] = terrain[i][j];
    }
  }
  
  // Smooth shorelines
  for (int i = 1; i < cols-1; i++) {
    for (int j = 1; j < rows-1; j++) {
      // Check if this is a shoreline cell (has both water and land neighbors)
      boolean isShore = false;
      boolean hasWater = false;
      boolean hasLand = false;
      
      // Check surrounding cells
      for (int di = -1; di <= 1; di++) {
        for (int dj = -1; dj <= 1; dj++) {
          int ni = i + di;
          int nj = j + dj;
          if (ni >= 0 && ni < cols && nj >= 0 && nj < rows) {
            if (terrain[ni][nj] <= 0) hasWater = true;
            if (terrain[ni][nj] > 0) hasLand = true;
          }
        }
      }
      
      isShore = hasWater && hasLand;
      
      // Apply shoreline smoothing
      if (isShore) {
        // For land cells near water, add a gentle slope (beach effect)
        if (terrain[i][j] > 0 && terrain[i][j] < 5) {
          float avgNeighbors = 0;
          int count = 0;
          
          for (int di = -1; di <= 1; di++) {
            for (int dj = -1; dj <= 1; dj++) {
              int ni = i + di;
              int nj = j + dj;
              if (ni >= 0 && ni < cols && nj >= 0 && nj < rows) {
                avgNeighbors += terrain[ni][nj];
                count++;
              }
            }
          }
          
          avgNeighbors /= count;
          
          // Create a smoother blend for beaches
          tempTerrain[i][j] = avgNeighbors * 0.7 + terrain[i][j] * 0.3;
          
          // Add some sand ripple effects
          tempTerrain[i][j] += noise(i * 0.3, j * 0.3) * 0.5;
        }
      }
    }
  }
  
  // Copy the smoothed values back
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      terrain[i][j] = tempTerrain[i][j];
    }
  }
}

void clearTerrain() {
  // Initialize terrain heights to zero (no terrain)
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      terrain[i][j] = 0;
    }
  }
  // Update water status
  updateWaterStatus();
}

void addTerrainAt(float x, float y, float strength) {
  // Add terrain at mouse position
  int centerI = int(x / cellSize);
  int centerJ = int(y / cellSize);
  
  // Apply to cells within brush radius
  for (int i = max(0, centerI - int(terrainBrushSize)); i < min(cols, centerI + int(terrainBrushSize)); i++) {
    for (int j = max(0, centerJ - int(terrainBrushSize)); j < min(rows, centerJ + int(terrainBrushSize)); j++) {
      float distance = dist(centerI, centerJ, i, j);
      
      // Only affect cells within the brush radius
      if (distance < terrainBrushSize) {
        float falloff = 1 - (distance / terrainBrushSize);
        falloff = falloff * falloff; // Square for smoother falloff
        
        // Add terrain with falloff
        terrain[i][j] += strength * falloff;
        
        // Add some noise for natural look
        terrain[i][j] += random(-0.2, 0.2) * strength * falloff;
        
        // Ensure terrain stays within reasonable bounds
        terrain[i][j] = constrain(terrain[i][j], 0, terrainAmplitude * 1.5);
      }
    }
  }
}

void lowerTerrainAt(float x, float y, float strength) {
  // Lower terrain at mouse position
  int centerI = int(x / cellSize);
  int centerJ = int(y / cellSize);
  
  // Apply to cells within brush radius
  for (int i = max(0, centerI - int(terrainBrushSize)); i < min(cols, centerI + int(terrainBrushSize)); i++) {
    for (int j = max(0, centerJ - int(terrainBrushSize)); j < min(rows, centerJ + int(terrainBrushSize)); j++) {
      float distance = dist(centerI, centerJ, i, j);
      
      // Only affect cells within the brush radius
      if (distance < terrainBrushSize) {
        float falloff = 1 - (distance / terrainBrushSize);
        falloff = falloff * falloff; // Square for smoother falloff
        
        // Lower terrain with falloff
        terrain[i][j] -= strength * falloff;
        
        // Add some noise for natural look
        terrain[i][j] += random(-0.1, 0.1) * strength * falloff;
        
        // Ensure terrain stays within reasonable bounds
        terrain[i][j] = constrain(terrain[i][j], 0, terrainAmplitude * 1.5);
      }
    }
  }
}

boolean isTerrainVisible(int i, int j) {
  // Check if this cell should show terrain rather than water
  if (i < 0 || i >= cols || j < 0 || j >= rows) return false;
  return terrain[i][j] > 0;
}

boolean isNearShore(int i, int j) {
  // Check if this water cell is near the shoreline for foam effects
  if (i >= cols-1 || j >= rows-1 || i <= 0 || j <= 0) return false;
  
  // Check surrounding cells for terrain
  for (int di = -1; di <= 1; di++) {
    for (int dj = -1; dj <= 1; dj++) {
      if (di == 0 && dj == 0) continue;
      int ni = i + di;
      int nj = j + dj;
      if (ni >= 0 && ni < cols && nj >= 0 && nj < rows) {
        if (isTerrainVisible(ni, nj)) {
          return true;
        }
      }
    }
  }
  
  return false;
}

void drawAtmosphericEffects() {
  // Add subtle gradient overlays for atmospheric effects
  
  // Top light source
  beginShape();
  fill(180, 200, 255, 3);
  vertex(0, 0);
  vertex(width, 0);
  fill(180, 200, 255, 0);
  vertex(width, height * 0.4);
  vertex(0, height * 0.4);
  endShape(CLOSE);
 
}

color[] createWaterColors() {
  color[] colors = new color[numWaterColors];
  
  // Modified colors to represent storm intensity
  colors[0] = color(5, 20, 45);      // Calm deep water
  colors[1] = color(15, 35, 70);     // Light chop
  colors[2] = color(30, 55, 100);    // Moderate waves
  colors[3] = color(50, 80, 130);    // Rough seas
  colors[4] = color(80, 110, 160);   // Storm beginning
  colors[5] = color(120, 150, 190);  // Storm center
  colors[6] = color(160, 190, 220);  // Hurricane/cyclone center
  
  return colors;
}

color[] createTerrainColors() {
  color[] colors = new color[numTerrainColors];
  
  // More distributed vegetation colors
  colors[0] = color(235, 225, 175);  // Beach sand
  colors[1] = color(180, 195, 130);  // Coastal grass
  colors[2] = color(130, 160, 95);   // Scattered vegetation
  colors[3] = color(95, 130, 75);    // Light forest
  colors[4] = color(70, 95, 55);     // Dense forest
  
  return colors;
}

color getWaterColor(float value) {
  float normalizedValue = constrain(value, 0, 1);
  float indexFloat = normalizedValue * (numWaterColors - 1);
  int index = int(indexFloat);
  
  // Get the two colors to blend between
  color c1 = waterColors[index];
  color c2 = waterColors[min(index + 1, numWaterColors - 1)];
  
  // Smoother interpolation
  float t = indexFloat - index;
  float blend = t * t * (3 - 2 * t);
  
  // Reduce noise variation for smoother appearance
  float variation = noise(value * 2, frameCount * 0.005) * 0.05;
  blend = constrain(blend + variation, 0, 1);
  
  return lerpColor(c1, c2, blend);
}

color getTerrainColor(float height) {
  // Enhanced color interpolation for terrain
  float normalizedHeight = constrain(map(height, 0, terrainAmplitude, 0, numTerrainColors - 0.01), 0, numTerrainColors - 0.01);
  int index = int(normalizedHeight);
  
  // Get the two colors to blend between
  color c1 = terrainColors[index];
  color c2 = terrainColors[min(index + 1, numTerrainColors - 1)];
  
  // Calculate blend factor with smoothstep interpolation
  float t = normalizedHeight - index;
  float blend = t * t * (3 - 2 * t); // Smoothstep interpolation
  
  // Add slight noise variation for more natural terrain
  float variation = noise(height * 0.5, frameCount * 0.005) * 0.15 - 0.075;
  blend = constrain(blend + variation, 0, 1);
  
  return lerpColor(c1, c2, blend);
}

void setCloudState(float x, float y) {
  int centerI = int(x / cellSize);
  int centerJ = int(y / cellSize);
  
  // Use current wave radius for state setting area
  float stateRadius = waveRadius * 1.2;
  
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      if (isWater[i][j]) {
        float dx = i - centerI;
        float dy = j - centerJ;
        float distance = sqrt(dx*dx + dy*dy);
        
        if (distance < stateRadius) {
          // Create falloff pattern from center
          float falloff = pow(1 - (distance / stateRadius), 1.5);
          
          // Set cell values and age
          float baseValue = 0.6 + random(-0.1, 0.1);
          cellValues[i][j] = baseValue * falloff;
          waveAge[i][j] = random(0, maxWaveAge * 0.2); // Start with random young age
          
          // Add some random variation for natural look
          if (random(1) < 0.3) {
            cellValues[i][j] *= random(0.8, 1.2);
          }
        }
      }
    }
  }
}

void keyPressed() {
  switch(key) {
    case 'x':
    case 'X':
      showInfo = !showInfo;
      break;
    case 'r': // Reset clouds
      initializeGrid();
      break;
    case 'n': // New terrain
      generateRandomTerrain();
      updateWaterStatus();
      break;
    case 'c': // Clear terrain
      clearTerrain();
      break;
    case 'g': // Toggle grid
      showGrid = !showGrid;
      break;
    case 't': // Toggle terrain mode
    case 'T':
      terrainMode = !terrainMode;
      lowerTerrainMode = false;
      break;
    case 'w': // Wind direction - North
      windDirX = 0.0;
      windDirY = -1.0;
      normalizeWindVector();
      break;
    case 's': // Wind direction - South
      windDirX = 0.0;
      windDirY = 1.0;
      normalizeWindVector();
      break;
    case 'a': // Wind direction - West
      windDirX = -1.0;
      windDirY = 0.0;
      normalizeWindVector();
      break;
    case 'd': // Wind direction - East
      windDirX = 1.0;
      windDirY = 0.0;
      normalizeWindVector();
      break;
  }
}

void normalizeWindVector() {
  // Normalize wind direction vector
  float magnitude = sqrt(windDirX*windDirX + windDirY*windDirY);
  if (magnitude > 0) {
    windDirX /= magnitude;
    windDirY /= magnitude;
  } else {
    // Default to rightward wind if zero
    windDirX = 1.0;
    windDirY = 0.0;
  }
}

void mousePressed() {
  if (terrainMode && mouseX >= 0 && mouseX < width && mouseY >= 0 && mouseY < height) {
    if (mouseButton == RIGHT) {
      lowerTerrainAt(mouseX, mouseY, terrainStrength);
      lastMousePos.set(mouseX, mouseY);
      updateWaterStatus();
    } else if (mouseButton == LEFT) {
      addTerrainAt(mouseX, mouseY, terrainStrength);
      lastMousePos.set(mouseX, mouseY);
      updateWaterStatus();
    }
  } else if (!terrainMode) {
    if (mouseButton == LEFT) {
      createCloud(mouseX, mouseY);
    } else if (mouseButton == RIGHT) {
      // Set propagation state at click location
      setCloudState(mouseX, mouseY);
    }
  }
}

void mouseWheel(MouseEvent event) {
  float e = event.getCount();
  
  if (keyPressed) {
    if (keyCode == SHIFT) {
      if (terrainMode) {
        terrainStrength = constrain(terrainStrength - e * 0.5, 1, 20);
      } else {
        // More precise wind speed adjustment (0.05 increments)
        windSpeed = constrain(windSpeed - e * 0.05, 0.1, 3.0);
      }
    } 
    else if (keyCode == ALT) {
      propagationRate = constrain(propagationRate - e * 0.05, 0.1, 1.0);
    }
  } else {
    if (terrainMode) {
      terrainBrushSize = constrain(terrainBrushSize - e * 1.5, 3, 40);
    } else {
      waveRadius = constrain(waveRadius - e * 1.0, 5, 40);
    }
  }
}

// Update the mouseDragged function for consistent behavior
void mouseDragged() {
  if (terrainMode && mouseX >= 0 && mouseX < width && mouseY >= 0 && mouseY < height) {
    if (mouseButton == RIGHT) {
      lowerTerrainAt(mouseX, mouseY, terrainStrength);
      lastMousePos.set(mouseX, mouseY);
      updateWaterStatus();
    } else if (mouseButton == LEFT) {
      addTerrainAt(mouseX, mouseY, terrainStrength);
      lastMousePos.set(mouseX, mouseY);
      updateWaterStatus();
    }
  } else if (!terrainMode) {
    if (mouseButton == LEFT) {
      createCloud(mouseX, mouseY);
    } else if (mouseButton == RIGHT) {
      setCloudState(mouseX, mouseY);
    }
  }
}

void drawCompass() {
  // Draw a compass in the top right showing wind direction
  int compassX = width - 60;
  int compassY = 60;
  int compassRadius = 40;
  
  // Draw compass background
  noStroke();
  fill(0, 0, 20, 70);
  ellipse(compassX, compassY, compassRadius * 2, compassRadius * 2);
  
  // Draw compass border
  stroke(200, 220, 255, 60);
  strokeWeight(1);
  noFill();
  ellipse(compassX, compassY, compassRadius * 2, compassRadius * 2);
  
  // Draw cardinal directions
  fill(180, 200, 255, 80);
  textAlign(CENTER, CENTER);
  textSize(12);
  text("N", compassX, compassY - compassRadius + 10);
  text("S", compassX, compassY + compassRadius - 10);
  text("W", compassX - compassRadius + 10, compassY);
  text("E", compassX + compassRadius - 10, compassY);
  
  // Draw crosshairs
  stroke(150, 180, 220, 40);
  line(compassX - compassRadius + 10, compassY, compassX + compassRadius - 10, compassY);
  line(compassX, compassY - compassRadius + 10, compassX, compassY + compassRadius - 10);
  
  // Draw wind direction arrow
  float arrowLength = compassRadius * 0.7 * windSpeed;
  float arrowWidth = 5;
  
  // Arrow body
  strokeWeight(3);
  stroke(240, 255, 255, 180);
  line(compassX, compassY, 
       compassX + windDirX * arrowLength, 
       compassY + windDirY * arrowLength);
  
  // Arrow head
  noStroke();
  fill(240, 255, 255, 180);
  
  pushMatrix();
  translate(compassX + windDirX * arrowLength, compassY + windDirY * arrowLength);
  rotate(atan2(windDirY, windDirX));
  beginShape();
  vertex(0, 0);
  vertex(-10, -arrowWidth);
  vertex(-7, 0);
  vertex(-10, arrowWidth);
  endShape(CLOSE);
  popMatrix();
  
  // Show minimal info when controls are hidden
  textAlign(CENTER, CENTER);
  textSize(12);
  fill(220, 240, 255, 150);  // Increased alpha for better visibility
  String speedText = "Wind Speed: " + nf(windSpeed, 0, 2);
  text(speedText, compassX, compassY + compassRadius + 15);
  
  // Show X for controls hint if info is hidden
  if (!showInfo) {
    text("Press X for controls", compassX, compassY + compassRadius + 30);
  }
}

void displayInfo() {
  // Always show compass
  drawCompass();
  
  // Return early if info display is hidden
  if (!showInfo) return;
  
  // Create info bar at bottom
  float barHeight = 100;
  float barY = height - barHeight;
  float lineHeight = 20;
  
  // Draw semi-transparent background
  noStroke();
  fill(0, 20, 40, 180);
  rect(0, barY, width, barHeight);
  
  // Draw separator line
  stroke(100, 150, 200, 60);
  line(0, barY, width, barY);
  
  // Set text properties
  textSize(14);
  fill(200, 220, 255, 200);
  
  float y1 = barY + lineHeight;
  float y2 = y1 + lineHeight;
  float y3 = y2 + lineHeight;
  float y4 = y3 + lineHeight;
  
  // Left section - Mode controls
  textAlign(LEFT, CENTER);
  if (terrainMode) {
    text("TERRAIN MODE", 10, y1);
    text("Size: " + int(terrainBrushSize) + " (Scroll)", 10, y2);
    text("Strength: " + nf(terrainStrength, 0, 1) + " (Shift+Scroll)", 10, y3);
    text("Left: Raise Terrain | Right: Lower Terrain", 10, y4);
  } else {
    text("WEATHER MODE", 10, y1);
    text("Size: " + int(waveRadius) + " (Scroll)", 10, y2);
    text("Wind: " + nf(windSpeed, 0, 2) + " (Shift+Scroll)", 10, y3);  // Show 2 decimal places
    text("Propagation: " + nf(propagationRate, 0, 1) + " (Alt+Scroll)", 10, y4);
  }
  
  // Center section
  float centerX = width/2 - 100;
  textAlign(LEFT, CENTER);
  text("CONTROLS", centerX, y1);
  text("T: Toggle Terrain Mode", centerX, y2);
  text("G: Toggle Grid " + (showGrid ? "[ON]" : "[OFF]"), centerX, y3);
  text("WASD: Change Wind Direction", centerX, y4);
  
  // Right section
  float rightX = width - 10;
  textAlign(RIGHT, CENTER);
  text("FPS: " + lastFrameRate, rightX, y1);
  text("R: Reset Waves", rightX, y2);
  text("N: New Terrain", rightX, y3);
  text("C: Clear Terrain", rightX, y4);
}
