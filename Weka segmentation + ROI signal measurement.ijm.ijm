/*
 * ============================================================================
 *  WEKA based image segmentation and per ROI signal quantification
 * ============================================================================
 */

// ------------------------- User parameters ---------------------------------
MODEL_FILE       = "golgi.model";
MIN_SIZE_PX2     = 1;      
MAX_SIZE_PX2     = "Infinity";
TARGET_BIT_DEPTH = 16;
// ---------------------------------------------------------------------------

setBatchMode(false);

// --- Locate golgi.model next to this macro --------------------------------
modelPath = MODEL_FILE;
if (!File.exists(modelPath)) {
    macroDir = "";
    p = getInfo("macro.filepath");
    if (p != "") macroDir = File.getParent(p) + File.separator;
    if (macroDir == "" || !File.exists(macroDir)) macroDir = getDirectory("imagej") + "macros/";
    modelPath = macroDir + MODEL_FILE;
}

inputDir  = getDirectory("Select input image folder");
outputDir = getDirectory("Select output folder");

list = getFileList(inputDir);
summary = "File\tParticleCount\tTotalArea_px2\tMeanArea_px2\tMean_Signal\n";

for (i = 0; i < list.length; i++) {
    f = list[i];
    if (!isImageFile(f) || endsWith(toLowerCase(f), "_mask.tif")) continue;
    print("Processing: " + f);

    // --- 1. Open and Normalize Original Image ---
    open(inputDir + f);
    base = File.getNameWithoutExtension(f);
    origID = getImageID();
    
    if (bitDepth() != TARGET_BIT_DEPTH) {
        setOption("ScaleConversions", true);
        if (TARGET_BIT_DEPTH == 8) run("8-bit");
        else                       run("16-bit");
        setOption("ScaleConversions", false);
    }

    run("Enhance Contrast", "saturated=0.35");

    // --- 2. Weka Classification ---
    selectImage(origID);
    run("Trainable Weka Segmentation");
    wait(1000); 
    call("trainableSegmentation.Weka_Segmentation.loadClassifier", modelPath);
    call("trainableSegmentation.Weka_Segmentation.getResult");
    wait(4000); 
    
    // Grab the classified image
    if (nImages() > 1) {
        selectImage(nImages()); 
        classified = getTitle();
    } else {
        print("  ERROR: Weka failed to produce a window.");
        close("*");
        continue;
    }

    // --- 3. Create Mask and Extract ROIs ---
    selectWindow(classified);
    
    // Use the exact settings from your manual workflow
    setAutoThreshold("Default dark");
    setOption("BlackBackground", true);
    run("Convert to Mask");
    
    // Save the visual outlines for the user
    run("Analyze Particles...", "size=" + MIN_SIZE_PX2 + "-" + MAX_SIZE_PX2 + " show=Outlines display overlay");
    if (isOpen("Drawing of " + classified)) {
        selectWindow("Drawing of " + classified);
        saveAs("PNG", outputDir + base + "_outlines.png");
    }
    
    // Add to ROI Manager (using your manual workflow)
    roiManager("reset");
    selectWindow(classified);
    run("Analyze Particles...", "size=" + MIN_SIZE_PX2 + "-" + MAX_SIZE_PX2 + " display overlay add");

    // Close the mask to clean up
    close(classified);
    if (isOpen("Drawing of " + classified)) close("Drawing of " + classified);
    run("Clear Results");

    // --- 4. Measure Signal on Original Image ---
    selectImage(origID);
    run("Set Measurements...", "area mean decimal=3");
    run("Clear Results");
    
    // Apply the ROIs directly to the original image (your manual step)
    run("From ROI Manager");
    roiManager("Measure");

    n = nResults;
    totalArea = 0;
    totalSignal = 0;

    // --- 5. Save CSV Safely ---
    if (isOpen("Particle_Data")) { selectWindow("Particle_Data"); run("Close"); }
    
    Table.create("Particle_Data");
    Table.setColumn("Index", newArray(n));
    Table.setColumn("Area", newArray(n));
    Table.setColumn("Mean_Signal", newArray(n));

    for (z = 0; z < n; z++) {
        p_area = getResult("Area", z);
        p_mean = getResult("Mean", z);
        
        totalArea = totalArea + p_area;
        totalSignal = totalSignal + p_mean;
        
        Table.set("Index", z, z+1);
        Table.set("Area", z, p_area);
        Table.set("Mean_Signal", z, p_mean);
    }

    selectWindow("Particle_Data");
    saveAs("Results", outputDir + base + "_particles.csv");

    // --- 6. Summary Stats ---
    if (n > 0) {
        meanArea = totalArea / n;
        meanSignal = totalSignal / n;
    } else {
        meanArea = 0;
        meanSignal = 0;
    }
    
    summary += base + "\t" + n + "\t" + totalArea + "\t" + meanArea + "\t" + meanSignal + "\n";
    
    // --- Cleanup ---
    close(origID);
    if (isOpen("Particle_Data")) { selectWindow("Particle_Data"); run("Close"); }
    if (isOpen("Results")) { selectWindow("Results"); run("Close"); }
}

// --- Write Summary File ---
f_out = File.open(outputDir + "SUMMARY.tsv");
print(f_out, summary);
File.close(f_out);
print("Pipeline Complete. Data saved to " + outputDir);

function isImageFile(name) {
    n = toLowerCase(name);
    return endsWith(n, ".tif") || endsWith(n, ".tiff") ||
           endsWith(n, ".png") || endsWith(n, ".jpg") || endsWith(n, ".jpeg");
}
