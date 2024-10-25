import pandas as pd
import sys
import json

json_file_path = sys.argv[1]
csv_file_path = sys.argv[2]

def move_column_inplace(df, col, pos):
    col = df.pop(col)
    df.insert(pos, col.name, col)

with open(json_file_path, encoding='utf-8') as f:
    data = json.loads(f.read())

if len(data['matches']) == 0:
    print("No data in sbom matches")
    exit(1)

data = data['matches']
data_as_json_filtered=list()
for record in data:
    record_filtered = dict()
    for key in list(record.keys()):
        if key=='relatedVulnerabilities':
            record_filtered.update({key: item for item in [time for time in record[key]]})
        elif key=='matchDetails':
            record_filtered.update({key: item for item in [source for source in record[key]]})
        elif key=='vulnerability':
            baseScore = 0
            for cvss_data in record[key]['cvss']:
                if cvss_data['metrics']['baseScore'] > baseScore:
                    baseScore = cvss_data['metrics']['baseScore']
            record_filtered.update({'vulnerability.cvss.max_baseScore': baseScore})
        else:
            record_filtered.update({key: record[key]})
    
    data_as_json_filtered.append(record_filtered)
jsonBody=pd.json_normalize(data_as_json_filtered)

if 'relatedVulnerabilities.urls' in jsonBody.columns:
    jsonBody.drop('relatedVulnerabilities.urls', axis=1, inplace = True)
    jsonBody.drop('relatedVulnerabilities.cvss', axis=1, inplace = True)

    jsonBody.drop('artifact.cpes', axis=1, inplace = True)

    jsonBody.sort_values(by=['vulnerability.cvss.max_baseScore'], ascending=False, inplace = True)

    move_column_inplace(jsonBody, 'relatedVulnerabilities.severity', 1)
    move_column_inplace(jsonBody, 'artifact.purl', 2)
    move_column_inplace(jsonBody, 'matchDetails.searchedBy.package.name', 3)
    move_column_inplace(jsonBody, 'matchDetails.searchedBy.package.version', 4)

jsonBody.to_csv(csv_file_path)

