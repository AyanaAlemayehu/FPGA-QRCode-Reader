# FPGA QR-Code Reader
We present a QR Code scanner implemented on an AMD Urbana FPGA, utilizing an OV7670 camera module to identify QR Codes and transmit the decoded information via HDMI to an external monitor. The OV7670 produces a 480x480 image that is subsequently converted to black and white and smoothed through convolutions to reduce graphical noise. Alignment patterns are used to locate the code, determine the module size, and generate the downsampled QR code for decoding. Upon decoding, the results are communicated to a computer via Manta. Our scanner can decode version-1 QR codes as small as 240x240 pixels in as fast as .02 seconds with possible optimizations to decrease the speed further.

## Hardware Requirements
- **AMD Urbana FPGA**
- **OV7670 camera module** mounted onto a Seeeduino Xiao SAMD21 (Arduino code included in the repository).

## Software Requiements
The only software requirement besides Vivado is [Manta](https://github.com/fischermoseley/manta), which is used to output the decoding results.

## Design and More Information
- [Final Report](https://github.com/msubhia/FPGA-QRCode-Reader/blob/main/6_2050_Final_Report.pdf) is an IEEE Formatted report contains the whole system structure including the decoding algorithm, system block diagram, and memory utilization, timing, and performance.
- [YouTube Video](https://www.youtube.com/watch?v=XbPQgtRze6U), gives a brief overview of the system's workings, and a super creative HDMI multiplexing illustrating the decoding process stage by stage.

## Main Directory Structure
- [custom_camera_firmware](https://github.com/msubhia/FPGA-QRCode-Reader/tree/main/custom_camera_firmware) includes the firmware, the camera module Arduino code.
- [hdl](https://github.com/msubhia/FPGA-QRCode-Reader/tree/main/hdl) includes the HDL code written using SystemVerilog.
- [sim](https://github.com/msubhia/FPGA-QRCode-Reader/tree/main/sim) includes some test benches used to help test and debug our system's functionality.
- [xdc](https://github.com/msubhia/FPGA-QRCode-Reader/blob/main/xdc/top_level.xdc) contains the .xdc constraints file.
- [qr_output](https://github.com/msubhia/FPGA-QRCode-Reader/blob/main/qr_output.py) contains a python script used to pass the output through Manta.

<br><br>
## For More information contact us at:
M.Subhi Abo Rdan: msubhi_a@mit.edu

Ayana Alemayehu:  ayana@mit.edu
