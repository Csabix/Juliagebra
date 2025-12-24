using Juliagebra

App()

A = Point(0,0,0)
B = Point(1,0,0)
C = Point(1,1,0)

Segment(A,B,color=(1,0,0),type=CURVE_ARROW,width=10.0f0)
Segment(C,B,color=(0,1,0),type=CURVE_DASHED,width=8.0f0)
Segment(C,A,color=[(0,1,0),(1,0,0)],width=3.0f0)

play!()