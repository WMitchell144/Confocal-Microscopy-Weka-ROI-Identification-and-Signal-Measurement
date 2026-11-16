/*
 * ============================================================================
 *  Golgi Segmenter
 *  Weka-based Golgi (GM130) segmentation + particle analysis for Fiji/ImageJ
 * ----------------------------------------------------------------------------
 *  Input: single-channel 16-bit TIFF of the Golgi marker.
 * ============================================================================
 */

// ------------------------- User parameters ---------------------------------
MODEL_FILE       = "golgi.model";
THRESH_METHOD    = "Intermodes dark";
MIN_SIZE_PX2     = 3;
MAX_SIZE_PX2     = "Infinity";
MIN_CIRC         = 0.00;
MAX_CIRC         = 0.95;
SAVE_OUTLINES    = true;
TARGET_BIT_DEPTH = 16;
// ---------------------------------------------------------------------------

// --- Locate golgi.model next to this macro --------------------------------
modelPath = MODEL_FILE;
if (!File.exists(modelPath)) {
    macroDir = "";
    p = getInfo("macro.filepath");
    if (p != "") macroDir = File.getParent(p) + File.separator;

    if (macroDir == "" || !File.exists(macroDir))
        macroDir = getDirectory("imagej") + "macros/";
    if (macroDir == "" || !File.exists(macroDir))
        macroDir = getDirectory("home") + "Documents/GitHub/";

    modelPath = macroDir + MODEL_FILE;
}

if (!File.exists(modelPath))
    exit("ERROR: " + MODEL_FILE + " not found.\nLooked in: " + macroDir);

print("Model path: " + modelPath);
// ---------------------------------------------------------------------------

inputDir  = getDirectory("Select input image folder");
outputDir = getDirectory("Select output folder");

header = "# Golgi Segmenter v1.0.3\n" +
         "# ImageJ " + getVersion() + "\n" +
         "# Java "   + getInfo("java.version") + "\n" +
         "# Model: " + modelPath + "\n" +
         "# Target bit depth: " + TARGET_BIT_DEPTH + "\n" +
         "# Threshold: " + THRESH_METHOD + "\n" +
         "# Size: " + MIN_SIZE_PX2 + "-" + MAX_SIZE_PX2 +
         "  Circularity: " + MIN_CIRC + "-" + MAX_CIRC + "\n";

list = getFileList(inputDir);
print("Files found: " + list.length);

summary = "File\tBitDepth_in\tParticleCount\tTotalArea_px2\tMeanArea_px2\n";

for (i = 0; i < list.length; i++) {
    f = list[i];
    if (!isImageFile(f)) continue;
    print("Processing: " + f);

    open(inputDir + f);
    base = File.getNameWithoutExtension(f);
    inDepth = bitDepth();

    // --- Normalize to 16-bit if necessary ---
    if (inDepth != TARGET_BIT_DEPTH) {
        setOption("ScaleConversions", true);
        if (TARGET_BIT_DEPTH == 8) run("8-bit");
        else                       run("16-bit");
        setOption("ScaleConversions", false);
        print("  Normalized " + inDepth + "-bit -> " + TARGET_BIT_DEPTH + "-bit");
    }

    // --- Enhance Contrast BEFORE Weka ---
    // Applies default histogram stretching (0.35% pixel saturation).
    // If your model prefers raw values, comment this out.
    run("Enhance Contrast", "saturated=0.35");

    // --- Weka session ---
    run("Trainable Weka Segmentation");
    wait(1000); // Let the GUI open

    call("trainableSegmentation.Weka_Segmentation.loadClassifier", modelPath);
    call("trainableSegmentation.Weka_Segmentation.getResult");
    
    // --- ACTIVE WAIT LOOP ---
    classified = "";
    for (attempt = 0; attempt < 40; attempt++) {
        wait(500);
        
        for (k = 1; k <= nImages(); k++) {
            selectImage(k);
            t = getTitle();
            if (startsWith(t, "Classified image")) { 
                classified = t; 
                break; 
            }
        }
        if (classified != "") break;
    }

    if (classified == "") {
        close("*");
        exit("Weka timed out after 20 seconds on " + f);
    }
    selectImage(classified);

    // --- Process Output ---
    run("8-bit");
    setAutoThreshold(THRESH_METHOD);
    setOption("BlackBackground", false);
    run("Convert to Mask");

    run("Set Measurements...", "area perimeter shape decimal=3");
    run("Analyze Particles...",
        "size=" + MIN_SIZE_PX2 + "-" + MAX_SIZE_PX2 +
        " circularity=" + MIN_CIRC + "-" + MAX_CIRC +
        " show=Outlines display include summarize overlay");

    selectWindow("Results");
    saveAs("Results", outputDir + base + "_particles.csv");

    if (SAVE_OUTLINES) {
        selectImage(classified);
        saveAs("PNG", outputDir + base + "_outlines.png");
    }

    n = nResults;
    total = 0;
    for (r = 0; r < n; r++) total += getResult("Area", r);
    
    if (n > 0) mean = total / n;
    else mean = 0;
    
    summary += base + "\t" + inDepth + "\t" + n + "\t" + total + "\t" + mean + "\n";

    close("*");
}

// Write Summary file
f = File.open(outputDir + "SUMMARY.tsv");
print(f, header);
print(f, summary);
File.close(f);
print("Done -> " + outputDir + "SUMMARY.tsv");

function isImageFile(name) {
    n = toLowerCase(name);
    return endsWith(n, ".tif") || endsWith(n, ".tiff") ||
           endsWith(n, ".png") || endsWith(n, ".jpg") || endsWith(n, ".jpeg");
}