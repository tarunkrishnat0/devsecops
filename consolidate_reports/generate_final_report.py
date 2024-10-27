import pandas as pd
import sys
import os

input_dir = sys.argv[1]
output_dir = sys.argv[2]

def print_columns(file_path):
    """
    Reads a CSV file and prints the column names.
    
    Parameters:
    - file_path (str): Path to the CSV file.
    """
    # Read the CSV file
    df = pd.read_csv(file_path)
    
    # Print the column names
    print("Columns in the CSV file:")
    for col in df.columns:
        print(col)

def remove_columns(input_file, output_file, columns_to_remove, columns_order):
    """
    Reads data from a CSV, removes specified columns, and saves to a new CSV file.
    
    Parameters:
    - input_file (str): Path to the input CSV file.
    - output_file (str): Path to the output CSV file.
    - columns_to_remove (list): List of column names to remove.
    """
    # Read the CSV file
    df = pd.read_csv(input_file)
    
    # Remove specified columns
    df.drop(columns=columns_to_remove, inplace=True, errors='ignore')
    
    for col_index in range(len(columns_order)):
        # print(columns_order[col_index])
        col_data = df.pop(columns_order[col_index])
        df.insert(col_index, columns_order[col_index], col_data)

    df.insert(5, "STATUS", "")
    df.insert(6, "REMARKS", "")

    # Save the updated dataframe to a new CSV file
    df.to_csv(output_file, index=False)
    print(f"File saved to {output_file} with columns {len(columns_to_remove)} removed.")


columns_to_remove = ['active', 'created', 'date', 'defect_review_requested_by', 'defect_review_requested_by_id', 'duplicate_finding', 'duplicate_finding_id',
                      'dynamic_finding', 'effort_for_fixing', 'epss_percentile', 'epss_score', 'false_p', 'finding_group',
                      'has_finding_group', 'has_jira_configured', 'has_jira_group_issue', 'has_jira_issue', 'impact', 'is_mitigated',
                      'last_reviewed', 'last_reviewed_by', 'last_reviewed_by_id', 'last_status_update', 'mitigated', 'mitigated_by',
                      'mitigated_by_id', 'mitigation', 'out_of_scope', 'param', 'payload', 'pk',
                      'planned_remediation_date', 'planned_remediation_version', 'publish_date', 'reporter_id', 'review_requested_by', 'review_requested_by_id',
                      'scanner_confidence', 'sla_age', 'sla_days_remaining', 'sla_deadline', 'sla_expiration_date', 'sla_start_date',
                      'sonarqube_issue', 'sonarqube_issue_id', 'static_finding', 'steps_to_reproduce', 'test', 'test_id',
                      'thread_id', 'under_defect_review', 'under_review', 'unique_id_from_tool', 'url', 'verified',
                      'violates_sla', 'vuln_id_from_tool', 'test.1', 'engagement_id', 'product_id',
                      'endpoints', 'severity_justification', 'service', 'hash_code', 'sast_sink_object', 'reporter', 'numerical_severity', 'risk_accepted'
                    ]
columns_order = ['file_path', 'line', 'severity', 'component_name', 'component_version', 'title', 'description', 'references', ]

os.makedirs(output_dir, exist_ok=True)

# Iterate over all files in the input directory
for filename in os.listdir(input_dir):
    # Check if the file is a CSV
    if filename.endswith('.csv'):
        input_file_path = os.path.join(input_dir, filename)
        output_file_path = os.path.join(output_dir, filename)

        # print_columns(input_csv)
        remove_columns(input_file_path, output_file_path, columns_to_remove, columns_order)
        # print_columns(output_file_path)