/*
 * Random non-overlapping control ROIs
 * -----------------------------------
 * Places `roi` non-overlapping squares covering `randomroifraction`% of the
 * image, draws them in red on a duplicate, and adds them to the ROI Manager.
 *
 * Reproducible: the RNG is seeded; the seed is printed to the Log.
 */

// ------------------------- parameters --------------------------------------
roi               = 240;    // number of control ROIs
randomroifraction = 10;     // % of image area covered by all ROIs together
SEED              = 12345;  // change per experiment; printed to Log
trials_per_roi    = 5000;   // max attempts per ROI before giving up
// ---------------------------------------------------------------------------

setRandomSeed(SEED);
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

        // Reject if the candidate square overlaps an already-painted (red) ROI
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
        exit("Failed to place ROI " + (z+1) + "/" + roi +
             " after " + trials_per_roi + " attempts. Placed: " + placed +
             ". Lower roi or randomroifraction.");
    }
    showProgress((z+1) / roi);
}

run("Select None");

// Populate ROI Manager
for (z = 0; z < roi; z++) {
    makeRectangle(xa[z], ya[z], side, side);
    roiManager("Add");
    roiManager("select", roiManager("count") - 1);
    roiManager("Rename", z + 1);
}

// Audit record -> Log
print("# control ROI generator");
print("# seed=" + SEED);
print("# roi=" + roi);
print("# randomroifraction=" + randomroifraction);
print("# image=" + imagewidth + "x" + imageheight);
print("# side=" + side);
print("# attempts_total=" + totalAttempts);
for (z = 0; z < roi; z++)
    print((z+1) + "\t" + xa[z] + "\t" + ya[z] + "\t" + side);