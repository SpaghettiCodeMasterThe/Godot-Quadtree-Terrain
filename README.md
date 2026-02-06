Design terrain with simplified version of terrain that let configure and see noises unlike the multithread version with use a class 
- Create the nodes, add the scripts.

![setup](https://github.com/user-attachments/assets/0744de19-3ecb-4670-9df0-24487bc8ec0e)
- Create terrain_design.material, change the path if needed -> terrain_design.gd -> @export var material: ShaderMaterial = preload("res://material/terrain_design.material")

![material](https://github.com/user-attachments/assets/ebae5220-4af6-42c4-910f-834f88735a13)

- Click on terrain node and you can keep the seed, change the max depth (subdivision) and node resolution, you can also see your material

![result](https://github.com/user-attachments/assets/ad2dd36c-4668-43cf-bd15-4505bc99fe97)

- Click on noise node to change noise settings, ! Uncheck keep seed and play with continent value for exemple, the noise script will find a seed with mostly terrain over water in the middle and return a valid seed, or it will tell you if it did not find any valid seed.
Exemple with lower continent noise frequency, it create a coastline:
- Continent flatness is how much we keep continent noise altitude, 1 mean the continent is flat, only spawning hill and mountain.

![coast](https://github.com/user-attachments/assets/75aa3d73-397c-4afa-8124-41fcf13c27b0)

- Change the smoothstep to a bigger value if the coast is too flat

![smoothstep](https://github.com/user-attachments/assets/03b56167-d0c5-4c15-ad1e-4b1865f5480f)

- You can change any value for the noise but the frequency need to be changed separatly (the 1/10000 tab) under it, for every noise there is a frequency

![noise](https://github.com/user-attachments/assets/25e6281e-4d11-4cae-8fa8-16cd42be832c)


