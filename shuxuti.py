#!/bin/python

import random

def generate_problem_with_answer():
    """随机生成一道加法或减法题，返回题目字符串和正确答案。"""
    if random.choice([True, False]):
        # 加法
        a = random.randint(1000, 9999)
        b = random.randint(1000, 9999)
        answer = a + b
        problem = f"{a} + {b} = "
    else:
        # 减法，结果为正
        a = random.randint(2000, 9999)
        b = random.randint(1000, a - 1)
        answer = a - b
        problem = f"{a} - {b} = "
    return problem, answer

def main():
    print("以下是为您生成的10道数学题（附答案）：\n")
    for i in range(1, 11):
        prob, ans = generate_problem_with_answer()
        print(f"{i:2}. {prob} {ans}")

if __name__ == "__main__":
    main()
