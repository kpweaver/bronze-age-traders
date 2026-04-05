import time
import pyautogui

# time to wait (seconds) before sending command
wait_time = 45 * 60   # 1 * 60 Minutes(1Hour) * 60 Seconds(1 Minute) = 1 hours
# or smaller e.g. 10 seconds
# wait_time = 10

print(f"Waiting {wait_time} seconds before sending command...")
time.sleep(wait_time)

# bring focus to the command prompt window manually before this fires
pyautogui.typewrite("continue, then make sure everything is working and then get started on the next task")
pyautogui.press("enter")