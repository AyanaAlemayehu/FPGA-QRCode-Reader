import time
from manta import Manta


m = Manta('qr_output.yaml') # create manta python instance using yaml

time.sleep(0.01) # wait a little amount...though honestly this is isn't needed since Python is slow.
block1 = m.lab8_io_core.block1_in.get()
block2 = m.lab8_io_core.block2_in.get()
block3 = m.lab8_io_core.block3_in.get()
block4 = m.lab8_io_core.block4_in.get()
block5 = m.lab8_io_core.block5_in.get()
length = m.lab8_io_core.length_in.get()
data_type = m.lab8_io_core.datatype_in.get()


total_blocks = format(block1, 'b') + format(block2, 'b') + format(block3, 'b') + format(block4, 'b') + format(block5, 'b')
decoded_blocks = ""
print("DECODED QR CODE:")
if data_type == 4:
    #this is bytes
    for i in range(length):
        if (total_blocks[i:i+8] != ''):
            decoded_blocks += total_blocks[i:i+8]

print(decoded_blocks)
print("data type: ", data_type)
print("length: " , length)
