import vapoursynth as vs
from vapoursynth import core 
clip = video_in

#You can change the desired framerate here
dst_fps = display_fps

#BlockSize can be changed to 16 for better performance
BlockSize=16

src_fps_num = int(container_fps * 1e8)
src_fps_den = int(1e8)
dst_fps_num = int(dst_fps * 1e4)
dst_fps_den = int(1e4)

# Needed because clip FPS is missing
clip = core.std.AssumeFPS(clip, fpsnum = src_fps_num, fpsden = src_fps_den)
print("Reflowing from ",src_fps_num/src_fps_den," fps to ",dst_fps_num/dst_fps_den," fps.")

#Pel can be changed to 4 for better accuracy or 1 for better speed
sup  = core.mv.Super(clip, pel=1, hpad=BlockSize, vpad=BlockSize)
bvec = core.mv.Analyse(sup, blksize=BlockSize, isb=True , chroma=True, search=3, searchparam=1)
fvec = core.mv.Analyse(sup, blksize=BlockSize, isb=False, chroma=True, search=3, searchparam=1)
clip = core.mv.BlockFPS(clip, sup, bvec, fvec, num=dst_fps_num, den=dst_fps_den, mode=3, thscd2=12)

clip.set_output()