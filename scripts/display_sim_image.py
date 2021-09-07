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
    file_orig_in = '../pictures/checkerboard_326x200.jpg'
    file_sim_in  = '../sim/video_out.yuv'
    verbose = 0
    display = 0

    # Check for input arguments
    try:
        opts, args = getopt.getopt(argv, "hvdi:", ["input="])
    except getopt.GetoptError:
        help()
        sys.exit(2)
    for opt, arg in opts:
        if opt == '-h':
            help()
            sys.exit()
        elif opt in ("-a", "--input1"):
            file_orig_in = arg
        elif opt in ("-b", "--input2"):
            file_sim_in = arg
        elif opt in ("-d"):
            display = 1
        elif opt in ("-v"):
            verbose = 1



    # Open image
    # open original image .jpg
    image_orig = mpimg.imread(file_orig_in)

    # Convert original image to grayscale
    gray_orig = rgb2gray(image_orig)


    # open simulation file .yuv
    filesim = open(file_sim_in, "rb")

    # Convert Image to grayscale
    #gray = rgb2gray(image)
    height, width = (199,326)
    temp_array = np.zeros(height*width)
    gray_sim = np.reshape(temp_array, (height, width))

    # Get image dimensions
    #height, width = gray.shape

    if (verbose):
        print("Height: %d" %(height))
        print("Width: %d" %(width))
        print(gray.size)
        print(gray[99][250])

    # unpack .yuv file to a grayscale array
    image_sim = filesim.read()
    for y in range(height):
        for x in range(width):
            gray_sim[y][x] = int(image_sim[(x*2)+(y*width*2)])


    # Close output file
    #fout.close

    if (display):
        fig, axs = plt.subplots(1, 2)
        axs[0].set_title('Original')
        axs[0].imshow(gray_orig, cmap=plt.get_cmap('gray'), vmin=0, vmax=255)
        axs[1].set_title('Corrected (Sim)')
        axs[1].imshow(gray_sim, cmap=plt.get_cmap('gray'), vmin=0, vmax=255)
        plt.show()

if __name__ == "__main__":
    main(sys.argv[1:])
