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
    width = 326
    height = 200
    strength = 1.7
    display = 0
    file_out = "corr_lut.mif"
    write_lut = 0
    try:
        opts, args = getopt.getopt(argv, "hdw:l:s:o:", ["width=", "lines=", "strength=", "output="])
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
        elif opt in ("-o", "--output"):
            write_lut = 1
            file_out = arg
        elif opt in ("-s", "--strength"):
            strength = float(arg)


    # Open output file
    if (write_lut):
        fout = open(file_out, "w")

    rd = math.sqrt((width ** 2) + (height ** 2)) / strength

    # Create the vectors X and Y
    pos = np.array(range(2048))
    newx = 0
    newy = 0
    for i in range(len(pos)):
        if (newx == width/2):
            if (newy != height/2):
                newy = newy + 1
        else:
            newx = newx + 1
        ru = math.sqrt((newx ** 2) + (newy ** 2))
        rnorm = ru/rd
        if (rnorm == 0.0):
            theta = 1
        else:
            theta = (math.atan(rnorm) / rnorm)
        # Calculate location in source image
        lut_val = format(int(theta * 2 ** 15), '05x')
        fout.write(lut_val)
        fout.write("\n")

    # Close output file
    fout.close



    #if (display):
    #    # Create the plot
    #    plt.plot(dstx[0:width-1],srcx[0:width-1], label = "columns")
    #    plt.plot(dsty[0:height-1],srcy[0:height-1], label = "rows")
    #    # Show the plot
    #    plt.show()

if __name__ == "__main__":
    main(sys.argv[1:])
