import numpy as np
import matplotlib.pyplot as plt
import matplotlib.image as mpimg
import sys, getopt

def help():
    print ('generate_image_rom.py -i <InputFile> -o <OutputFile>')
    print ('-v : verbose')
    print ('-d : display image')

def rgb2gray(rgb):
    return np.dot(rgb[...,:3], [0.2989, 0.5870, 0.1140])

def main(argv):
    # Default values
    file_in  = '../pictures/checkerboard_326x200.jpg'
    file_out = 'image_in.mif'
    verbose = 0
    display = 0

    # Check for input arguments
    try:
        opts, args = getopt.getopt(argv, "hvdi:o:", ["input=", "output="])
    except getopt.GetoptError:
        help()
        sys.exit(2)
    for opt, arg in opts:
        if opt == '-h':
            help()
            sys.exit()
        elif opt in ("-i", "--input"):
            file_in = arg
        elif opt in ("-o", "--output"):
            file_out = arg
        elif opt in ("-d"):
            display = 1
        elif opt in ("-v"):
            verbose = 1



    # Open image
    image = mpimg.imread(file_in)
    # Open output file
    fout = open(file_out, "w")

    # Convert Image to grayscale
    gray = rgb2gray(image)

    # Get image dimensions
    height, width = gray.shape

    if (verbose):
        print("Height: %d" %(height))
        print("Width: %d" %(width))
        print(gray.size)
        print(gray[99][250])

    # Write to output file
    for y in range(height):
        for x in range(width):
            lut_val = format(int(gray[y][x]), '02x')
            fout.write(lut_val)
            fout.write("\n")

    # Close output file
    fout.close

    if (display):
        plt.imshow(gray, cmap=plt.get_cmap('gray'), vmin=0, vmax=255)
        plt.show()

if __name__ == "__main__":
    main(sys.argv[1:])
