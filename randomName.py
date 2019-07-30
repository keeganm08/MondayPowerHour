#print(ord('A'),ord('Z')) # 65, 90 gets ascii value  chr(65) gets character value
#print(ord('a'),ord('z')) # 97, 122 gets ascii value chr(97) gets character value


import random

def randChar(amount):
    charList = ""
    vowel = ['a','e','i','o','u']
    for i in range(0,amount):
        if i < 1:
            charList += str(chr(random.randint(65,90)))
        else:
            if i % random.randint(1,3) == 0:
                charList += random.choice(vowel)
            else:
                charList += str(chr(random.randint(97,122)))
    return charList

print(randChar(random.randint(4,10)),randChar(random.randint(4,10)))