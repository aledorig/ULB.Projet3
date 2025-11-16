# temporaire i guess, juste pour voir en visuel
import matplotlib.pyplot as plt
import numpy as np

from perlin import Perlin


noise = Perlin(seed=550)

width  = 300
height = 300
scale  = 0.05

img = np.zeros((height, width))

for y in range(height):
    for x in range(width):
        n = noise.perlin(x * scale, y * scale)
        img[y][x] = n

plt.imshow(img, cmap="gray")
plt.title("Perlin Noise")
plt.axis("off")
plt.show()
