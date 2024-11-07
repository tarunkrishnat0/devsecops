from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.remote.client_config import ClientConfig
from selenium.webdriver.support.wait import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

from dotenv import load_dotenv
from pathlib import Path
import os
import requests
import json

dotenv_path = Path('configs/env')
load_dotenv(dotenv_path=dotenv_path)

DEFECT_DOGO_URL = os.getenv('DEFECT_DOGO_URL')

windows_download_path = os.path.expanduser("~/Downloads")

# Set up Chrome options for headless download
chrome_options = webdriver.ChromeOptions()
chrome_options.add_experimental_option("prefs", {
    "download.default_directory": windows_download_path,
    "download.prompt_for_download": False,
    "download.directory_upgrade": True,
    "safebrowsing.enabled": True
})

driver = webdriver.Chrome(options=chrome_options)
driver.set_page_load_timeout(60*10) # 10mins
driver.get(DEFECT_DOGO_URL+"/login?next=/reports/csv_export?url=/engagement/1/finding/all")
# title = driver.title
# print(title)

username_field = driver.find_element(by=By.NAME, value="username")
password_field = driver.find_element(by=By.NAME, value="password")

username_field.send_keys(os.getenv('DEFECT_DOJO_USER'))
password_field.send_keys(os.getenv('DEFECT_DOJO_PASSWD'))

# Submit the form (either click the login button or press Enter)
login_button = driver.find_element(By.CLASS_NAME, "btn-success")  # Update selector as needed
login_button.click()

# with open('page.html', 'w+') as f:
#     f.write(driver.page_source)

# driver.implicitly_wait(180)
# driver.quit()

# try:
#     element = WebDriverWait(driver, 60*10).until(
#         EC.presence_of_element_located((By.ID, "csv_export"))
#     )
# finally:
#     driver.quit()
