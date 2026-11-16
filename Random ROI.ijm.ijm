/*
 * ============================================================================
 *  Random non-overlapping control ROIs (Batch version)
 * ----------------------------------------------------------------------------
 *  Places `roi` non-overlapping squares covering `randomroifraction`% of the
 *  image, saves an image with the squares drawn on it (.png), and saves the
 *  coordinates as a .csv. Loops through an entire folder of images.
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
    
    // FIXED: use random("seed", SEED) instead of setRandomSeed()
    random("seed", SEED);
    roiManager("reset");

    imagewidth  = getWidth();
    imageheight = getHeight();
    imagearea   = imagewidth * imageheight;

    // Side length of each square
    totalTarget = imagearea * randomroifraction / 100.0;
    side        = sqrt(totalTarget / roi);

    // Scratch canvas: duplicate, 8-bit, RGB to paint red squares
    run("Duplicate...", "title=control_roi");
    run("8-bit");
    run("RGB Color");
    setForegroundColor(255, 0, 0);

    xa = newArray(roi);
    ya = newArray(roi);
    placed = 0;
    totalAttempts = 0;

    for (z = 0; z < roi; z++) {
        ok = false;
        for (t = 0; t < trials_per_roi; t++) {
            totalAttempts++;
            x = floor(random() * (imagewidth  - side));
            y = floor(random() * (imageheight - side));

            // Reject if the candidate square overlaps an already-painted ROI
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
            exit("Failed to place ROI " + (z+1) + "/" + roi +
                 " after " + trials_per_roi + " attempts on " + f + 
                 ". Placed: " + placed + ". Lower roi or randomroifraction.");
        }
        showProgress((z+1) / roi);
    }

    run("Select None");

    // --- EXPORT IMAGE ---
    selectImage("control_roi");
    saveAs("PNG", outputDir + base + "_controlROIs.png");

    // --- EXPORT CSV ---
    audit = "index\tx\ty\tside\n";
    for (z = 0; z < roi; z++)
        audit += (z+1) + "\t" + xa[z] + "\t" + ya[z] + "\t" + side + "\n";
        
    f_out = File.open(outputDir + base + "_controlROIs.csv");
    print(f_out, audit);
    File.close(f_out);

    print("  Saved PNG and CSV. Seed used: " + SEED);
    
    close("*");
}

print("Done -> " + outputDir);

function isImageFile(name) {
    n = toLowerCase(name);
    return endsWith(n, ".tif") || endsWith(n, ".tiff") ||
           endsWith(n, ".png") || endsWith(n, ".jpg") || endsWith(n, ".jpeg");
}