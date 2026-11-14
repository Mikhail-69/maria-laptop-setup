#!/usr/bin/env python3
import subprocess
import time

RUS_TO_ENG = {
    'й': 'q', 'ц': 'w', 'у': 'e', 'к': 'r', 'е': 't', 'н': 'y', 'г': 'u', 'ш': 'i', 'щ': 'o', 'з': 'p',
    'х': '[', 'ъ': ']', 'ф': 'a', 'ы': 's', 'в': 'd', 'а': 'f', 'п': 'g', 'р': 'h', 'о': 'j', 'л': 'k',
    'д': 'l', 'ж': ';', 'э': "'", 'я': 'z', 'ч': 'x', 'с': 'c', 'м': 'v', 'и': 'b', 'т': 'n', 'ь': 'm',
    'б': ',', 'ю': '.', 'Ё': '~', 'ё': '`', 'Й': 'Q', 'Ц': 'W', 'У': 'E', 'К': 'R', 'Е': 'T', 'Н': 'Y',
    'Г': 'U', 'Ш': 'I', 'Щ': 'O', 'З': 'P', 'Х': '{', 'Ъ': '}', 'Ф': 'A', 'Ы': 'S', 'В': 'D', 'А': 'F',
    'П': 'G', 'Р': 'H', 'О': 'J', 'Л': 'K', 'Д': 'L', 'Ж': ':', 'Э': '"', 'Я': 'Z', 'Ч': 'X', 'С': 'C',
    'М': 'V', 'И': 'B', 'Т': 'N', 'Ь': 'M', 'Б': '<', 'Ю': '>'
}
ENG_TO_RUS = {v: k for k, v in RUS_TO_ENG.items()}

def get_clipboard():
    result = subprocess.run(['xclip', '-o', '-selection', 'clipboard'], capture_output=True, text=True)
    return result.stdout

def set_clipboard(text):
    subprocess.run(['xclip', '-i', '-selection', 'clipboard'], input=text, text=True)

def fix_language(text):
    if not text:
        return text
    result = []
    for c in text:
        if c in RUS_TO_ENG:
            result.append(RUS_TO_ENG.get(c, c))
        elif c in ENG_TO_RUS:
            result.append(ENG_TO_RUS.get(c, c))
        else:
            result.append(c)
    return ''.join(result)

def main():
    time.sleep(0.05)
    subprocess.run(['xdotool', 'key', 'ctrl+c'], capture_output=True)
    time.sleep(0.05)
    text = get_clipboard()
    if text:
        fixed = fix_language(text)
        set_clipboard(fixed)
        time.sleep(0.05)
        subprocess.run(['xdotool', 'key', 'ctrl+v'], capture_output=True)

if __name__ == "__main__":
    main()
