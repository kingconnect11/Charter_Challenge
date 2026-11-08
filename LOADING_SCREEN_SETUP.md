# Loading Screen Setup Instructions

## Where to Add Your Background Image

### Step 1: Add Image to Assets Catalog

1. **Open Xcode** and navigate to your project
2. **Find the Assets folder** in the Project Navigator:
   ```
   CharterChallenge/
   └── CharterChallenge/
       └── Assets.xcassets/
   ```

3. **Right-click** on `Assets.xcassets` folder
4. Select **"New Image Set"**
5. **Name it**: `ongBackground` (exactly as shown - case sensitive!)

### Step 2: Add Your Image Files

1. **Click** on the `LoadingBackground` image set you just created
2. You'll see slots for different image sizes:
   - **1x** (for older devices)
   - **2x** (for Retina displays)
   - **3x** (for Retina HD displays)

3. **Drag and drop** your background image into the appropriate slots:
   - If you have one image, drag it to **2x** (most common)
   - If you have multiple sizes, use the appropriate slots
   - The image should be at least **1242x2688 pixels** for best quality on all devices

### Step 3: Verify Image Name

The code expects the image to be named **`LoadingBackground`** (case-sensitive).

If you want to use a different name:
1. Open `CharterChallenge/Views/LoadingView.swift`
2. Find line 12: `Image("LoadingBackground")`
3. Change `"LoadingBackground"` to your image name

### Step 4: Image Recommendations

For best results, your background image should:
- Be **high resolution** (at least 1242x2688 for iPhone)
- Have a **landscape or portrait orientation** that works well
- Not have important details in the center (where text/progress bar will be)
- Be optimized for file size (use JPEG or compressed PNG)

### Current Setup

The loading screen will:
- Display your background image as a full-screen background
- Show "Charter Challenge" title in the center-top
- Display an animated progress bar showing loading percentage
- Automatically transition to the main app when loading completes

The progress bar updates as the app loads:
- **33%** - Vessels loaded
- **66%** - Captains loaded  
- **100%** - Crew loaded, ready to play!



