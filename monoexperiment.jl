include("monoqueue.jl")

queue = Queue{QueueLockAble}()
cars = []


for i in 1:6
    car = Car("C$(string(i))")
    push!(cars,car)
    println(car.name)
end

for i in 1:5
    enqueue!(queue,cars[2])
end

for i in 1:3
    enqueue!(queue,cars[5])
end

enqueue!(queue,cars[6])

println("Dequeing!")

while(!isempty(queue))
    car = dequeue!(queue)
    println(car.name)
end
