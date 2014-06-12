Wavey Checkers Compute Example
==============================

The same as the previous wavey checkers example, except uses a compute shader to generate the checkered texture instead of a fragment shader. But it generates it only once prior to the render loop (as the texture does not change itself). Side note: Currently the kernel isn't as effecient as the fragment shader, in tests it seems to be about 4-5 times slower.

Additionally all the buffers have been combined into one single buffer, as suggested by their docs. Buffers are allocated as VM pages, so it's best not to waste memory (if something is much smaller than the page size) and pack our content into them. And uses multiple time variables (our only render loop modified data) along with a semaphore to try reduce the occurrence of a frame accessing an incorrect time.