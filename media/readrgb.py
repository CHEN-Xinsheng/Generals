from PIL import Image
import numpy as np

L_path='city.png'
L_image=Image.open(L_path)
out = L_image
print(type(out))
img=np.array(out)

print(out.size)
print(img.shape)#高 宽 三原色分为三个二维矩阵
from pprint import pprint
pprint(img.tolist())
# with open('rgb.txt', 'wb') as f:
#     f.write(img.tolist())