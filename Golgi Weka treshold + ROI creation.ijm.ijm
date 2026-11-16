/*
 * ============================================================================
 *  Golgi Segmenter
 *  Weka-based Golgi (GM130) segmentation + particle analysis for Fiji/ImageJ
 * ----------------------------------------------------------------------------
 *  Repository:  https://github.com/WMitchell144/Confocal-microscopy-Weka-ROI-identification-and-Signal-measurement
 *  License:     MIT (see LICENSE)
 *  Version:     1.0.0
 *  Tested on:   Fiji/ImageJ 2.x, Trainable Weka Segmentation (bundled with Fiji)
 *
 *  Quick start:
 *    1. Clone the repo. Keep golgi.model next to this macro.
 *    2. Open in Fiji: Plugins > Macros > Run... (choose this file)
 *    3. Pick an input folder of images and an output folder.
 *    4. Results: <image>_particles.csv, <image>_outlines.png, SUMMARY.tsv
 *
 *  If this tool helps your work, please cite:
 *    Arganda-Carreras I et al. Trainable Weka Segmentation.
 *    Bioinformatics. 2017.  doi:10.1093/bioinformatics/btw632
 * ============================================================================
 */

// ------------------------- User parameters ---------------------------------
MODEL_FILE    = "golgi.model";        // relative to macro folder, or absolute
THRESH_METHOD = "Intermodes dark";    // see README > "Why Intermodes?"
MIN_SIZE_PX2  = 3;
MAX_SIZE_PX2  = "Infinity";
MIN_CIRC      = 0.00;
MAX_CIRC      = 0.95;                 // <1 excludes near-perfect circles; see README
SAVE_OUTLINES = true;
// ---------------------------------------------------------------------------

macroFolder = getDirectory("macros");
modelPath = MODEL_FILE;
if (!File.exists(modelPath)) modelPath = macroFolder + MODEL_FILE;
if (!File.exists(modelPath)) exit("ERROR: model not found: " + modelPath);

inputDir  = getDirectory("Select input image folder");
outputDir = getDirectory("Select output folder");

header = "# Golgi Segmenter v1.0.0\n" +
         "# ImageJ " + getVersion() + " | " + IJ.getVersion() + "\n" +
         "# Java "   + System.getProperty("java.version") + "\n" +
         "# Model: " + modelPath + "\n" +
         "# Threshold: " + THRESH_METHOD + "\n" +
         "# Size: " + MIN_SIZE_PX2 + "-" + MAX_SIZE_PX2 +
         "  Circularity: " + MIN_CIRC + "-" + MAX_CIRC + "\n";

list = getFileList(inputDir);
summary = "File\tParticleCount\tTotalArea_px2\tMeanArea_px2\n";

setBatchMode(true);
for (i = 0; i < list.length; i++) {
    f = list[i];
    if (!isImageFile(f)) continue;

    open(inputDir + f);
    base = File.getNameWithoutExtension(f);

    call("trainableSegmentation.Weka_Segmentation.loadClassifier", modelPath);
    call("trainableSegmentation.Weka_Segmentation.getResult");
    selectImage("Classified image");

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
        selectWindow("Classified image");
        saveAs("PNG", outputDir + base + "_outlines.png");
    }

    n = nResults;
    total = 0;
    for (r = 0; r < n; r++) total += getResult("Area", r);
    mean = (n > 0) ? total / n : 0;
    summary += base + "\t" + n + "\t" + total + "\t" + mean + "\n";

    close("*");
}
setBatchMode(false);

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