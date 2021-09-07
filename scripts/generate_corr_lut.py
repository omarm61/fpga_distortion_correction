# Import our modules that we are using
import matplotlib.pyplot as plt
import numpy as np
import math
import sys
import getopt

def print_help():
    print ("./generate_corr_lut.py -w <width> -l <height>")
    print ("-d : Plot LUTs")
    print ("-h : Help message")

def main(argv):
    Rsrc = 212
    width = 326
    height = 200
    centerx = width/2
    centery = height/2
    strength = 1.7
    display = 0
    try:
        opts, args = getopt.getopt(argv, "hdw:l:s:", ["width=", "lines=", "strength="])
    except getopt.GetoptError:
        print_help()
        sys.exit(2)

    for opt, arg in opts:
        if opt == '-h':
            print_help()
            sys.exit()
        elif opt in ("-w", "--width"):
            width = int(arg)
        elif opt in ("-l", "--lines"):
            height = int(arg)
        elif opt in ("-d", "--height"):
            display = 1
        elif opt in ("-s", "--strength"):
            strength = float(arg)

    rd = math.sqrt((width ** 2) + (height ** 2)) / strength

    # Source Location
    srcx = np.zeros(width)
    srcy = np.zeros(height)

    # Create the vectors X and Y
    dstx = np.array(range(width))
    dsty = np.array(range(height))
    for j in range(len(dsty)):
        for i in range(len(dstx)):
            newx = i - centerx
            newy = j - centery
            ru = math.sqrt((newx ** 2) + (newy ** 2))
            rnorm = ru/rd
            if (rnorm == 0.0):
                theta = 1
            else:
                theta = (math.atan(rnorm) / rnorm)
            # Calculate location in source image
            srcx[i] = int(round(centerx + theta * newx))
            srcy[j] = int(round(centery + theta * newy))

    if (display):
        # Create the plot
        plt.plot(dstx[0:width-1],srcx[0:width-1], label = "columns")
        plt.plot(dsty[0:height-1],srcy[0:height-1], label = "rows")
        # Show the plot
        plt.show()

if __name__ == "__main__":
    main(sys.argv[1:])
