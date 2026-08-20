imagewidth = getWidth();
imageheight = getHeight();
imagearea = imagewidth*imageheight;
roi=240 // Nb of ROI to create
randomroifraction=10 // % of image occupied by a single ROI
randomroidivisor = 100/randomroifraction;
randomroitotalarea = imagearea/randomroidivisor;
randomroiarea = randomroitotalarea/roi;
w = sqrt(randomroiarea);
h = sqrt(randomroiarea);
trials = roi*10; //maximum trials to avoid infinite loop
setForegroundColor(255,0,0);
kk=0;

run("Duplicate...", "title=randomroi");
randomroiID = getImageID();
run("8-bit"); //make it greyscale
run("RGB Color"); //RGB to display colours

do {

    if (kk==10) {
        beep();
        exit("Not enough space to draw random non-overlapping ROIs on the image. Reduce random ROIs fraction.");
    }

    ii=0;
    jj=0;
    xa=newArray(roi);
    ya=newArray(roi);

    while (ii<roi && jj<trials) {
        x = random()*(imagewidth-w);
        y = random()*(imageheight-h);
        jj++;
        //Check for pixels with value (255,0,0):
        flag= -1;
        makeRectangle(x, y, w, h);
        //Scanning the rectangle perimeter should be faster than scanning the whole box.
        //This is slower, as checks all the points in the box:
        for (xs=x;xs<x+w;xs++){
            for (ys=y;ys<y+h;ys++){
                if (getPixel(xs,ys)==-65536) // pixel is (255,0,0)
                    flag=0;
            }
        }
        if (flag==-1) {
            xa[ii]=x;
            ya[ii]=y;
            run("Fill");
            ii++;
        }
    }

    kk++;

} while (xa[roi-1]==0 && ya[roi-1]==0);

    for (z=0;z<roi;z++) {
        makeRectangle(xa[z], ya[z], w, h);
           roiManager("Add");
        roiManager("select", roiManager("count")-1);
        roiManager("Rename", z+1);
    }

selectImage(randomroiID);
close();