class_name Queue
extends RefCounted

var cellArray : Array[Vector2]
var front : int
var rear : int
var itemCount : int

func _init() -> void:
	cellArray = []
	front = 0
	rear = -1
	itemCount = 0
	
func pop() -> Vector2:
	var cell := cellArray[front]
	removeData()
	return cell

func top() -> Vector2:
	return cellArray[front]

func isEmpty():
	return itemCount == 0

func size():
	return itemCount

func push(data:Vector2):
	rear += 1
	cellArray.append(data)
	itemCount += 1

func removeData():
	var data = cellArray[front]
	front += 1
	itemCount -= 1
	return data

#def main():
#	insert(3)
#	insert(5)
#	insert(9)
#	insert(1)
#	insert(12)
#	insert(15)
#	print("Queue size: ", size())
#	print("Queue: ")
#	for i in range(MAX):
#		print(intArray[i], end = " ")
#	if isFull():#
#		print("\nQueue is full!")
#	num = removeData()
#	print("Element removed: ", num)
#	print("Queue size after deletion: ", size())
#	print("Element at front: ", peek())
