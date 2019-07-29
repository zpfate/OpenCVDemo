//
//  ViewController.m
//  OpenCVDemo
//
//  Created by Twisted Fate on 2019/7/25.
//  Copyright © 2019 Twisted Fate. All rights reserved.
//

#import <opencv2/opencv.hpp>

#import "ViewController.h"

#import <opencv2/imgproc/imgproc.hpp>
#import <opencv2/imgproc/imgproc_c.h>
#import <opencv2/imgproc/types_c.h>
#import <opencv2/imgcodecs/ios.h>

@interface ViewController ()

@end


using namespace cv;
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    newAction(@"", @"");
    
    
}

void newAction(NSString *str, NSString *name) {

}

void colorFilter(CvMat *inputImage, CvMat *&outputImage) {
    
    int i, j;
    IplImage *image = cvCreateImage(cvGetSize(inputImage), 8, 3);
    cvGetImage(inputImage, image);
    IplImage *hsv = cvCreateImage( cvGetSize(image), 8, 3 );
    cvCvtColor(image, hsv, CV_RGB2HSV);
    int width = hsv->width;
    int height = hsv->height;
    for (i = 0; i < height; i++)
        for (j = 0; j < width; j++) {
            CvScalar s_hsv = cvGet2D(hsv, i, j);//获取像素点为（j, i）点的HSV的值
            
            /*
             opencv 的H范围是0~180，红色的H范围大概是(0~8)∪(160,180)
             S是饱和度，一般是大于一个值,S过低就是灰色（参考值S>80)，
             V是亮度，过低就是黑色，过高就是白色(参考值220>V>50)。
             */
            CvScalar s;
            if (!(((s_hsv.val[0]>0)&&(s_hsv.val[0]<8)) || ((s_hsv.val[0] > 120) && (s_hsv.val[0]<180)))) {
                s.val[0] = 0;
                s.val[1] = 0;
                s.val[2] = 0;
                cvSet2D(hsv, i ,j, s);
            }
        }
    outputImage = cvCreateMat( hsv->height, hsv->width, CV_8UC3 );
    cvConvert(hsv, outputImage);
    namedWindow("filter");
    //    cvShowImage("filter", hsv);
    waitKey(0);
    cvReleaseImage(&hsv);
}



- (IBAction)colorFilterAction:(id)sender {
    
    UIImage *originImage = [UIImage imageNamed:@"miss.jpeg"];
    NSLog(@"originImage ===== %@", originImage);
//
//    Mat inputMat;
//    UIImageToMat(originImage, inputMat);
//
//    CvMat *inputCvMat = nullptr;
//    CvMat temp = inputMat; //转化为CvMat类型，而不是复制数据
//    cvCopy(&temp, inputCvMat); //真正复制数据 cvCopy使用前要先开辟内存空间
//
//    CvMat *outputCvMat;
//    colorFilter(inputCvMat, outputCvMat);
    
//    Mat b = Mat
//
//    MatToUIImage(b);
    // openCV
    
    
    // 使用CoreImage
    /***
     
     1.创建一个映射希望移除颜色值范围的立方体贴图cubeMap，将目标颜色的alpha置为0.0f
     2. 使用CIColorCube滤镜和cubeMap对源图像进行颜色处理
     3.获取到经过CIColorCube处理的Core Image对象CIImage,转换为Core Graphics中的CGImageRef对象，通过imageWithCGImage:获取结果图片
     注意: 第三步中，不可以直接使用imageWithCIImage:,因为得到的并不是一个标准的UIImage，如果直接拿来用，会出现不显示的情况
     */

    UIImage *putImage = [self tf_colorFilterWithImage:originImage maxHueAngle:170 minHueAngle:50];
    NSLog(@"%@", putImage);
}


- (UIImage *)tf_colorFilterWithImage:(UIImage *)originImage maxHueAngle:(float)maxHueAngle minHueAngle:(float)minHueAngle {
    
    CIImage *ciImage = [CIImage imageWithCGImage:originImage.CGImage];
    CIContext *context = [CIContext contextWithOptions:nil];
    /** 注意
     * UIImage通过CIImage初始化 得到的并不是一个通过类似CGImage的标准的UIImage
     * 如果不用context渲染处理，无法正常显示
     */
    
    CIImage *renderBgImage = [self outputImageWithOriginalCIImage:ciImage minHueAngle:minHueAngle maxHueAngle:maxHueAngle];
    CGImageRef renderImage = [context createCGImage:renderBgImage fromRect:ciImage.extent];
    UIImage *image = [UIImage imageWithCGImage:renderImage];
    return image;
}

struct CubeMap {
    int length;
    float dimension;
    float *data;
};

- (CIImage *)outputImageWithOriginalCIImage:(CIImage *)originalImage minHueAngle:(float)minHueAngle maxHueAngle:(float)maxHueAngle{
    
    struct CubeMap map = createCubeMap(minHueAngle, maxHueAngle);
    const unsigned int size = 64;
    // Create memory with the cube data
    NSData *data = [NSData dataWithBytesNoCopy:map.data
                                        length:map.length
                                  freeWhenDone:YES];
    CIFilter *colorCube = [CIFilter filterWithName:@"CIColorCube"];
    [colorCube setValue:@(size) forKey:@"inputCubeDimension"];
    // Set data for cube
    [colorCube setValue:data forKey:@"inputCubeData"];
    
    [colorCube setValue:originalImage forKey:kCIInputImageKey];
    CIImage *result = [colorCube valueForKey:kCIOutputImageKey];
    
    return result;
}

struct CubeMap createCubeMap(float minHueAngle, float maxHueAngle) {
    const unsigned int size = 64;
    struct CubeMap map;
    map.length = size * size * size * sizeof (float) * 4;
    map.dimension = size;
    float *cubeData = (float *)malloc (map.length);
    float rgb[3], hsv[3], *c = cubeData;
    
    for (int z = 0; z < size; z++){
        rgb[2] = ((double)z)/(size-1); // Blue value
        for (int y = 0; y < size; y++){
            rgb[1] = ((double)y)/(size-1); // Green value
            for (int x = 0; x < size; x ++){
                rgb[0] = ((double)x)/(size-1); // Red value
                rgbToHSV(rgb,hsv);
                // Use the hue value to determine which to make transparent
                // The minimum and maximum hue angle depends on
                // the color you want to remove
                float alpha = (hsv[0] > minHueAngle && hsv[0] < maxHueAngle) ? 0.0f: 1.0f;
                // Calculate premultiplied alpha values for the cube
                c[0] = rgb[0] * alpha;
                c[1] = rgb[1] * alpha;
                c[2] = rgb[2] * alpha;
                
                if ((hsv[0] > minHueAngle && hsv[0] < maxHueAngle)) {
                    alpha = 0;
                } else {
                    alpha = 1;
                }
                c[3] = alpha;
                c += 4; // advance our pointer into memory for the next color value
            }
        }
    }
    map.data = cubeData;
    return map;
}

void rgbToHSV(float *rgb, float *hsv) {
    float min, max, delta;
    float r = rgb[0], g = rgb[1], b = rgb[2];
    float *h = hsv, *s = hsv + 1, *v = hsv + 2;
    
    min = fmin(fmin(r, g), b );
    max = fmax(fmax(r, g), b );
    *v = max;
    delta = max - min;
    if( max != 0 )
        *s = delta / max;
    else {
        *s = 0;
        *h = -1;
        return;
    }
    if( r == max )
        *h = ( g - b ) / delta;
    else if( g == max )
        *h = 2 + ( b - r ) / delta;
    else
        *h = 4 + ( r - g ) / delta;
    *h *= 60;
    if( *h < 0 )
        *h += 360;
}

- (IBAction)faceDetection:(id)sender {
    
    
    
}


@end
