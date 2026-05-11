#include <opencv2/opencv.hpp>
#include <iostream>

using namespace std;
using namespace cv;

int main() {
    CascadeClassifier face_cascade;
    if (!face_cascade.load("haarcascade_frontalface_default.xml")) {
        cout << "--(!) Error: Cannot load cascade" << endl;
        return -1;
    }

    VideoCapture capture(0, CAP_DSHOW); 
    if (!capture.isOpened()) {
        cout << "--(!) Error: Cannot connect to camera" << endl;
        return -1;
    }

    Mat frame, frame_gray, small_gray;
    const int TARGET_WIDTH = 320;
    const int TARGET_HEIGHT = 240;

    // สร้างออบเจกต์ CLAHE (ตั้งค่า Limit ความสว่างที่ 2.0 และแบ่งกริดขนาด 8x8)
    Ptr<CLAHE> clahe = createCLAHE(2.0, Size(8, 8));

    cout << "Press 'q' or 'ESC' to quit..." << endl;

    while (capture.read(frame)) {
        if (frame.empty()) break;

        // 1. แปลงเป็น Grayscale
        cvtColor(frame, frame_gray, COLOR_BGR2GRAY);
        
        // 2. ย่อขนาดภาพให้เท่ากับ Buffer ของฮาร์ดแวร์จริง
        resize(frame_gray, small_gray, Size(TARGET_WIDTH, TARGET_HEIGHT));
        
        // 3. ใช้ CLAHE แทน equalizeHist แบบเก่า (ช่วยให้จับหน้าในที่มืด/ย้อนแสงได้โคตรดี)
        clahe->apply(small_gray, small_gray);

        std::vector<Rect> faces;
        
        // 4. จูนพารามิเตอร์เพื่อเน้นความ "ชัวร์" (Accuracy)
        face_cascade.detectMultiScale(
            small_gray, 
            faces, 
            1.1,        // ScaleFactor: ลดลงมาเป็น 1.1 เพื่อให้มันค่อยๆ ซูมหาหน้าทีละ 10% (ช้าลงนิด แต่ละเอียดและแม่นขึ้นมาก)
            6,          // MinNeighbors: ขยับขึ้นเป็น 6 ต้องมั่นใจจริงๆ ถึงจะตีกรอบ (ลดกรอบมั่วตามกำแพงหรือเสื้อผ้า)
            0, 
            Size(24, 24), // MinSize: ขนาดเล็กสุด
            Size(150, 150) // MaxSize: ขนาดใหญ่สุด
        );

        float scale_x = (float)frame.cols / TARGET_WIDTH;
        float scale_y = (float)frame.rows / TARGET_HEIGHT;

        for (size_t i = 0; i < faces.size(); i++) {
            int x = cvRound(faces[i].x * scale_x);
            int y = cvRound(faces[i].y * scale_y);
            int w = cvRound(faces[i].width * scale_x);
            int h = cvRound(faces[i].height * scale_y);
            
            // เปลี่ยนกรอบเป็นสีฟ้าอมน้ำเงิน
            rectangle(frame, Point(x, y), Point(x+w, y+h), Scalar(255, 100, 0), 2);
        }

        imshow("High Accuracy Face Detection (CLAHE)", frame);

        char c = (char)waitKey(10);
        if (c == 27 || c == 'q' || c == 'Q') break;
    }
    
    return 0;
}