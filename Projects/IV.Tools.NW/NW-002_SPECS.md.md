# Purpose

Bluerush has offered Nationwide to handle the processing of their data and they accepted. Shaun Ito from Nationwide is the sole person responsible for manipulating the information coming from Nationwide’s IT department, which represents a huge liability if Shaun is to ever move on from his position at Nationwide, putting then a risk on the licence for this video itself.

## Current data management

Shaun Ito provided this **screenshare walkthrough** of his manual data manipulations: [NW-002 Pet - storyboards & data review-20241223_140659-Meeting Recording.mp4](https://bluerushgroup-my.sharepoint.com/:v:/r/personal/warren_tang_bluerush_com/Documents/Recordings/NW-002%20Pet%20-%20storyboards%20%26%20data%20review-20241223_140659-Meeting%20Recording.mp4?csf=1&web=1&e=bLjCsv&nav=eyJyZWZlcnJhbEluZm8iOnsicmVmZXJyYWxBcHAiOiJTdHJlYW1XZWJBcHAiLCJyZWZlcnJhbFZpZXciOiJTaGFyZURpYWxvZy1MaW5rIiwicmVmZXJyYWxBcHBQbGF0Zm9ybSI6IldlYiIsInJlZmVycmFsTW9kZSI6InZpZXcifX0%3D "https://bluerushgroup-my.sharepoint.com/:v:/r/personal/warren_tang_bluerush_com/Documents/Recordings/NW-002%20Pet%20-%20storyboards%20%26%20data%20review-20241223_140659-Meeting%20Recording.mp4?csf=1&web=1&e=bLjCsv&nav=eyJyZWZlcnJhbEluZm8iOnsicmVmZXJyYWxBcHAiOiJTdHJlYW1XZWJBcHAiLCJyZWZlcnJhbFZpZXciOiJTaGFyZURpYWxvZy1MaW5rIiwicmVmZXJyYWxBcHBQbGF0Zm9ybSI6IldlYiIsInJlZmVycmFsTW9kZSI6InZpZXcifX0%3D")  
(request video access from @Warren Tang )

## **Steps:**

1. **Shaun receives data files from IT** (usually 2)  
    More about the data itself:
    1. **Same format**: these files always have the same formats and same column order.
    2. **Content**: IT returns a list of all their clients that are at the 6 month mark since their insurance started.
2. **Shaun executes data management steps** as defined in this document: We couldn't load the file.
3. **Shaun copies the final list to a master list** that contains all the previous recipients created.
4. **Shaun uploads the data file** through the Portal to create the recipients.
5. **Shaun provides a separate file for the email campaign provider** with full PURLs included.

## **Original project BRD**

[NW-002 Pet IndiVideo BRD v1.1 - 2024 01 05.docx](https://bluerushgroup.sharepoint.com/:w:/s/Projects/EaLf4M67OlFKm1xGYlWjnbYBYAkV4VorPYaqbIPFtBmYWQ?e=nAiK8A "https://bluerushgroup.sharepoint.com/:w:/s/Projects/EaLf4M67OlFKm1xGYlWjnbYBYAkV4VorPYaqbIPFtBmYWQ?e=nAiK8A")

# Requirements

Since this will all be automated, first step is to have a drop location for the data that is 1) on US soil, and 2) a viable solution for low/medium tech level.

|   |
|---|
|to-do Establish and train client on a new drop location for the data files.|

**US data**  
All Nationwide data downloads and data manipulation done by Bluerush _**MUST**_ be handled on US soil.

## Data manipulation

Bluerush will be automating everything below for Nationwide.

1. **BR to execute data management steps** as defined in this document: We couldn't load the file.  
    Simplified:
    1. **Delete** row 1-2, and column A for each file separately
    2. **Filter** rows:
        1. **Remove** blank “Insured Email Address”
        2. **Keep** only applicable plans **[see table below]**
        3. **Remove** CA MM and WP non-renewals
        4. **Keep** “Pet Species” of values “Canine” and “Feline” only
        5. **Remove** when “Age” is above 30
    3. **Add** column:
        
        1. **“Unique ID**” by combining “Insured code” + “Policy number”
        2. **“Statement Date**” with the file’s date (found in the file name: New Marketing Report-**2025-01-13**-11-52-21.xlsx )
    4. **Modify** values:
        
        1. **Populate wellness for POIA and VBW plans.** Note that this is only needed if wellness is not already displaying.
        2. **Transform type** to Number for these columns:
            1. “Deductible”
            2. “Claimed Amount”
            3. “Claimed Paid Amount”
        3. **Transform type** to General for “Co Payment”
        4. **Transform value** for “Insured First Name” to proper first name (Capitalize first letter of every word)
    5. **Remove** columns
        1. **[MORE INFO REQUIRED]**
    6. **Final check**:
        1. “Unique ID” are **unique**
        2. **Compare against master list**: no duplicate “Unique ID”  
            If duplicate is found, remove processing file row & leave master list as-is (i.e. master list is the source of truth). This is only done in the off chance that Nationwide IT’s list includes a recipient that was already created. If that’s the case, they don’t want to accidently send over the same person a renewal video email again. However, there could be duplicates if it’s a listing form last year. So there should be an allowance for an annual refresh.
1. **BR to create the recipients**  
    Batch upload.
2. **BR to maintain a master list** that contains all the previous recipients created.  
    Append new batch rows.
3. **BR to send back a file to Shaun** with full PURLs  
    Expected format: Full populated table with all rows/data, along with the Unique prod PURL for each user

### Eligible Plans:

**For the last year, this has been Major Medical, POIB and MPP non-wellness plans. Here are the products to keep from our product mapping chart:**

|   |   |   |
|---|---|---|
|**BASE PRODUCT CODE**|**POI OR BENEFIT SCHEDULE**|**DISPLAY NAME**|
|GMM250T|BS|Major Medical|
|MM100T|BS|Major Medical|
|MM250T|BS|Major Medical|
|POIB25050L|POI|Whole Pet|
|POIB25070L|POI|Whole Pet|
|POIB25090L|POI|Whole Pet|
|VB25050|POI|My Pet Protection|
|VB25070|POI|My Pet Protection|
|VB25090|POI|My Pet Protection|
|MM100|BS|Major Medical|
|MM1000|BS|Major Medical|
|MM1000T|BS|Major Medical|
|MM250|BS|Major Medical|
|MM500|BS|Major Medical|
|MM500T|BS|Major Medical|
|POIA10050||Whole Pet with Wellness|
|POIA10070||Whole Pet with Wellness|
|POIA10090||Whole Pet with Wellness|
|POIA25090||Whole Pet with Wellness|
|VBWL525050||My Pet Protection with Wellness|
|VBWL525070||My Pet Protection with Wellnes|