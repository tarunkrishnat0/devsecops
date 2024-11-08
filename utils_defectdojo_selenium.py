from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.remote.client_config import ClientConfig
from selenium.webdriver.support.wait import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

from dotenv import load_dotenv
from pathlib import Path
import os
import time
import sys

dotenv_path = Path('configs/env')
load_dotenv(dotenv_path=dotenv_path)
DEFECT_DOGO_URL = os.getenv('DEFECT_DOGO_URL')

def format_size(size_in_bytes):
    # Format the size into KB or MB as appropriate
    if size_in_bytes < 1024:
        return f"{size_in_bytes} bytes"
    elif size_in_bytes < 1024 ** 2:
        return f"{size_in_bytes / 1024:.2f} KB"
    else:
        return f"{size_in_bytes / (1024 ** 2):.2f} MB"

def create_driver(download_path="~/Downloads/"):
    windows_download_path = os.path.abspath(download_path)
    # print(windows_download_path)

    # Set up Chrome options for headless download
    chrome_options = webdriver.ChromeOptions()
    chrome_options.add_argument('--headless')
    chrome_options.add_experimental_option("prefs", {
        "download.default_directory": windows_download_path,
        "download.prompt_for_download": False,
        "download.directory_upgrade": True,
        "safebrowsing.enabled": True,
        # "detach": True
    })

    driver = webdriver.Chrome(options=chrome_options)
    # driver.set_page_load_timeout(60*10) # 10mins
    
    return driver


def login_to_defectdojo(driver):
    username_field = driver.find_element(by=By.NAME, value="username")
    password_field = driver.find_element(by=By.NAME, value="password")

    username_field.send_keys(os.getenv('DEFECT_DOJO_USER'))
    password_field.send_keys(os.getenv('DEFECT_DOJO_PASSWD'))

    # Submit the form (either click the login button or press Enter)
    login_button = driver.find_element(By.CLASS_NAME, "btn-success")  # Update selector as needed
    login_button.click()


def download_findings_from_defectdojo(engagement_id, download_path):
    findings_path = os.path.join(download_path, "findings.csv")
    print('Downloading to '+findings_path)

    if os.path.isfile(findings_path):
        print('################')
        print('File exits at path ' + findings_path)
        print('Deleting this file')
        os.remove(findings_path)
        print('################')

    driver = create_driver(download_path)
    
    driver.get(DEFECT_DOGO_URL+"/login?next=/reports/csv_export?url=/engagement/"+str(engagement_id)+"/finding/all")

    login_to_defectdojo(driver)

    # title = driver.title
    # print(title)

    # with open('page.html', 'w+') as f:
    #     f.write(driver.page_source)

    print("Waiting for findings to be downloaded.", end='')
    while True:
        if os.path.isfile(findings_path):
            break
        else:
            sys.stdout.flush()
            time.sleep(1)
            print('.', end='')

    print()
    print('Downloaded findings to' + download_path+"/findings.csv")

    # driver.implicitly_wait(180)
    driver.quit()

    # try:
    #     element = WebDriverWait(driver, 60*10).until(
    #         EC.presence_of_element_located((By.ID, "csv_export"))
    #     )
    # finally:
    #     driver.quit()

def create_engagment_in_defectdojo(engagement_name):
    driver = create_driver()
    
    driver.get(DEFECT_DOGO_URL+"/login?next=/product/1/new_engagement/cicd")

    login_to_defectdojo(driver)

    name_field = driver.find_element(by=By.ID, value="id_name")
    name_field.send_keys(engagement_name)

    done_button = driver.find_element(By.XPATH, "//input[@value='Done']")
    done_button.click()

    try:
        WebDriverWait(driver, 60*10).until(
            EC.presence_of_element_located((By.CLASS_NAME, "alert"))
        )
        print('Engagment Created: '+engagement_name)
    finally:
        driver.quit()

if __name__ == "__main__":
    #engagement_id = sys.argv[1]
    #download_path = sys.argv[2]
    #download_findings_from_defectdojo(engagement_id, download_path)
    create_engagment_in_defectdojo("test-ttk")
