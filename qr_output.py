import time
from manta import Manta
import binascii



m = Manta('qr_output.yaml') # create manta python instance using yaml

time.sleep(0.01) # wait a little amount...though honestly this is isn't needed since Python is slow.
block1 = m.lab8_io_core.block1_in.get()
block2 = m.lab8_io_core.block2_in.get()
block3 = m.lab8_io_core.block3_in.get()
block4 = m.lab8_io_core.block4_in.get()
block5 = m.lab8_io_core.block5_in.get()
length = m.lab8_io_core.length_in.get()
data_type = m.lab8_io_core.datatype_in.get()


## NUmber of bits correction
blocks = [block1, block2, block3, block4, block5]
total_blocks = ""
for b in blocks:
    total_blocks += "0"*(32 - len(format(b, "b"))) + format(b, "b")


print("data type: ", data_type)
print("data length: " , length)

print("DECODED QR CODE:")
decoded_blocks = ""

for i in range(length):
    if (total_blocks[i*8:i*8+8] != ''):
        n = int(total_blocks[i*8:i*8 + 8], 2)
        print(n.to_bytes((n.bit_length() + 7) // 8, 'big').decode(), end="")
print("")# adds a newline char
