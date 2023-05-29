from PIL import Image  
import numpy as np  
Image = Image.open('9.png')   
Image_array = np.array(Image) 
print(Image_array.shape)
from pprint import pprint
pprint(Image_array.tolist())
import matplotlib.pyplot as pyplot
 
contents = []
for i in range(40):
    for j in range(40):
        for k in range(4):
            contents.append(int(Image_array[i][j][k]))
with open('9.mif', 'w') as wf:
    print('WIDTH = 32;', file=wf)
    print('DEPTH = 6400;', file=wf)
    print('ADDRESS_RADIX = HEX;', file=wf)
    print('DATA_RADIX = HEX;', file=wf)

    print('CONTENT BEGIN', file=wf)
    n = len(contents) // 4
    for k in range(n):
        alpha = contents[4 * k + 3]#int.from_bytes(contents[4 * k + 0], 'little')
        red   = contents[4 * k + 0]#int.from_bytes(contents[4 * k + 1], 'little')
        green = contents[4 * k + 1]#int.from_bytes(contents[4 * k + 2], 'little')
        blue  = contents[4 * k + 2]#int.from_bytes(contents[4 * k + 3], 'little')
        if k==0:
            print(alpha, red, green, blue)
        print('%04X: %02X%02X%02X%02X;' % (k, alpha, blue, green, red), file=wf)
    print('END;', file=wf)