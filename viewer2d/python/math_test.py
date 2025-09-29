
import sys

def add_test(a, b):
    return a + b

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python math_test.py a b")
        sys.exit(1)
    a = float(sys.argv[1])
    b = float(sys.argv[2])
    result = add_test(a, b)
    print(result)
