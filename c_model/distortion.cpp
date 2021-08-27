#include <opencv2/opencv.hpp>
#include <stdio.h>
#include <iostream>
#include <math.h>

using namespace std;
using namespace cv;

int verbose = 1;


// Distortion Correction- Eq: ru = rd + (k1 * rd^3) + (k2 * rd^5)
void DistCorrPoly5(const Mat& srcImg, Mat& dstImg, Point pPoint) {
    const double k1 = 0.0005;
    const double k2 = 0.0;
    const double k3 = -0.152;
    const double k4 = 0.0;
    const double zoom = 0.5;
    double rd;
    double ru;
    double rNorm;
    double theta;
    int newX;
    int newY;
    int srcX;
    int srcY;

    dstImg = srcImg.clone();

    rd = sqrt(pow(srcImg.rows, 2) + pow(srcImg.cols, 2)) * zoom;

    for (int j = 0; j < dstImg.rows; ++j)
    {
        for (int i = 0; i < dstImg.cols; i++)
        {
            newX = i - pPoint.x;
            newY = j - pPoint.y;
            ru = sqrt(pow(newX, 2) + pow(newY, 2));
            rNorm = ru / rd;
            //theta = atan(r) / (r);
            if (rNorm == 0.0)
                theta = 1;
            else
                theta = ((pow(rNorm, 5) * k1) + (pow(rNorm, 4) * k2) + (pow(rNorm, 3) * k3) + (pow(rNorm, 2) * k4) + rNorm)/rNorm;

            srcX = round(pPoint.x + theta*newX);
            srcY = round(pPoint.y + theta*newY);

            dstImg.at<char>(j, i) = srcImg.at<char>(srcY, srcX);
        }
    }
}

// Distortion Correction- Eq: ru = arctan(10p1rd)/(10p1)
void DistCorrAtan(const Mat& srcImg, Mat& dstImg, Point pPoint,  double strength) {
    double rd;
    double ru;
    double rNorm;
    double theta;
    int newX;
    int newY;
    int srcX;
    int srcY;

    dstImg = srcImg.clone();

    rd = sqrt(pow(srcImg.rows, 2) + pow(srcImg.cols, 2)) / strength;

    for (int j = 0; j < dstImg.rows; ++j)
    {
        for (int i = 0; i < dstImg.cols; i++)
        {
            newX = i - pPoint.x;
            newY = j - pPoint.y;
            ru = sqrt(pow(newX, 2) + pow(newY, 2));
            rNorm = ru / rd;
            if (rNorm == 0.0)
                theta = 1;
            else
                theta = atan(rNorm) / (rNorm);

            srcX = round(pPoint.x + theta*newX);
            srcY = round(pPoint.y + theta*newY);

            dstImg.at<char>(j, i) = srcImg.at<char>(srcY, srcX);
        }
    }
}


int main() {

    Mat srcImg;
    Mat dstImgPoly;
    Mat dstImgAtan;
    Point pPoint; // Center of distortion

    // Load Image
    srcImg = imread("../pictures/checkerboard_326x200.jpg", IMREAD_GRAYSCALE);   // Read the file
    if (srcImg.empty())                              // Check for invalid input
    {
        cout << "Could not find file" << endl;
        return -1;
    }


    // principal point
    pPoint = Point(srcImg.cols / 2,
                   srcImg.rows / 2);
    if (verbose) {
        cout << "Image Width:" << srcImg.cols << endl;
        cout << "Image Height:" << srcImg.rows << endl;
        cout << "Image Channel:" << srcImg.channels() << endl;
        cout << "Image Data:" << +srcImg.at<uint8_t>(pPoint.y,pPoint.x) << endl;
    }

    //circle(srcImg, x, 4, Scalar(0, 0, 255), FILLED, LINE_8);
    drawMarker(srcImg, pPoint, Scalar(0, 0, 255), MARKER_CROSS, 10, 1, LINE_8);
    namedWindow("Raw Image", WINDOW_AUTOSIZE);// Create a window for display.
    imshow("Raw Image", srcImg);                   // Show our image inside it.

    //waitKey(0);                                          // Wait for a keystroke in the window


    // Correct Image Poly 5
    DistCorrPoly5(srcImg, dstImgPoly, pPoint);

    // Correct Image Atan
    DistCorrAtan(srcImg, dstImgAtan, pPoint, 1.7);

    // Draw Corrected Poly image
    namedWindow("Corrected Poly5", WINDOW_AUTOSIZE);
    imshow("Corrected Poly5", dstImgPoly);                   // Show our image inside it.
    //
    // Draw Corrected Atan image
    namedWindow("Corrected Atan", WINDOW_AUTOSIZE);
    imshow("Corrected Atan", dstImgAtan);                   // Show our image inside it.
    waitKey(0);

    return 0;
}
