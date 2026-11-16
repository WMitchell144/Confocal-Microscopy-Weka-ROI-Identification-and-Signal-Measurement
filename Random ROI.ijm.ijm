/*
 * ============================================================================
 *  Random non-overlapping control ROIs (Batch version with Signal Measurement)
 * ============================================================================
 */

// ------------------------- parameters --------------------------------------
roi               = 240;    // number of control ROIs per image
randomroifraction = 10;     // % of image area covered by all ROIs together
SEED              = 12345;  // change per experiment; printed to Log
trials_per_roi    = 5000;   // max attempts per ROI before giving up
// ---------------------------------------------------------------------------

setBatchMode(false);

inputDir  = getDirectory("Select input image folder");
if (inputDir == "") exit("No input folder selected.");

outputDir = getDirectory("Select output folder");
if (outputDir == "") exit("No output folder selected.");

list = getFileList(inputDir);
print("Files found: " + list.length);

for (i = 0; i < list.length; i++) {
    f = list[i];
    if (!isImageFile(f)) continue;
    print("Processing: " + f);

    open(inputDir + f);
    base = File.getNameWithoutExtension(f);
    origID = getImageID(); 
    
    random("seed", SEED);
    roiManager("reset");
    run("Clear Results");

    imagewidth  = getWidth();
    imageheight = getHeight();
    imagearea   = imagewidth * imageheight;

    totalTarget = imagearea * randomroifraction / 100.0;
    side        = sqrt(totalTarget / roi);

    // Scratch canvas to paint red squares
    run("Duplicate...", "title=control_roi");
    run("8-bit");
    run("RGB Color");
    setForegroundColor(255, 0, 0);

    xa = newArray(roi);
    ya = newArray(roi);
    placed = 0;
    totalAttempts = 0;

    // --- STEP 1: GENERATE ROIs ---
    for (z = 0; z < roi; z++) {
        ok = false;
        for (t = 0; t < trials_per_roi; t++) {
            totalAttempts++;
            x = floor(random() * (imagewidth  - side));
            y = floor(random() * (imageheight - side));

            makeRectangle(x, y, side, side);
            flag = -1;
            for (xs = x; xs < x + side; xs++)
                for (ys = y; ys < y + side; ys++)
                    if (getPixel(xs, ys) == -65536) flag = 0;

            if (flag == -1) {
                run("Fill");
                xa[z] = x;
                ya[z] = y;
                placed++;
                ok = true;
                break;
            }
        }
        if (!ok) {
            beep();
            close("*");
            exit("Failed to place ROI " + (z+1) + "/" + roi + " on " + f);
        }
        showProgress((z+1) / roi);
    }
    run("Select None");

    // --- STEP 2: EXPORT VISUAL PNG ---
    selectImage("control_roi");
    saveAs("PNG", outputDir + base + "_controlROIs.png");

    // --- STEP 3: MEASURE SIGNAL ON ORIGINAL IMAGE ---
    selectImage(origID);
    run("Set Measurements...", "mean decimal=3");
    run("Clear Results");
    
    roiManager("reset");
    for (z = 0; z < roi; z++) {
        makeRectangle(xa[z], ya[z], side, side);
        roiManager("Add");
    }
    
    // Measure all 240 ROIs on the original 16-bit image
    roiManager("Measure");

    // --- STEP 4: EXPORT SAFE CSV ---
    Table.create("ROI_Data");
    
    Table.setColumn("Index", newArray(roi));
    Table.setColumn("X", newArray(roi));
    Table.setColumn("Y", newArray(roi));
    Table.setColumn("Side", newArray(roi));
    Table.setColumn("Mean_Signal", newArray(roi));

    for (z = 0; z < roi; z++) {
        m_mean = getResult("Mean", z);
        
        Table.set("Index", z, z+1);
        Table.set("X", z, xa[z]);
        Table.set("Y", z, ya[z]);
        Table.set("Side", z, side);
        Table.set("Mean_Signal", z, m_mean);
    }

    // Save the robust table as the final CSV
    selectWindow("ROI_Data");
    saveAs("Results", outputDir + base + "_controlROIs_Signal.csv");

    print("  Saved PNG and Signal CSV. Seed used: " + SEED);
    close("*");
}

print("Done -> " + outputDir);

function isImageFile(name) {
    n = toLowerCase(name);
    return endsWith(n, ".tif") || endsWith(n, ".tiff") ||
           endsWith(n, ".png") || endsWith(n, ".jpg") || endsWith(n, ".jpeg");
}