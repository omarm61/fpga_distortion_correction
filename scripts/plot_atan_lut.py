# Import our modules that we are using
import matplotlib.pyplot as plt
import numpy as np
import math
import sys
import getopt

def print_help():
    print ("./plot_lut.py -g <gamma ratio>")

def main(argv):
    Rsrc = 212
    length = 20
    try:
        opts, args = getopt.getopt(argv, "r:l:", ["radius=", "length="])
    except getopt.GetoptError:
        print_help()
        sys.exit(2)

    for opt, arg in opts:
        if opt == '-h':
            print_help()
            sys.exit()
        elif opt in ("-r", "--radius"):
            Rsrc = float(arg)
        elif opt in ("-l", "--length"):
            length = int(arg)

    # Create the vectors X and Y
    x = np.array(range(length))
    y = np.zeros(length)
    for i in range(len(x)):
        y[i] = (math.atan(x[i]) / Rsrc)

    # Create the plot
    plt.plot(x[0:length],y[0:length])

    # Show the plot
    plt.show()

if __name__ == "__main__":
    main(sys.argv[1:])


