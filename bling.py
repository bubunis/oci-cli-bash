import oci
import os

# This script downloads all of the usage reports for a tenancy (specified in the config file)
#
# Pre-requisites: Create an IAM policy to endorse users in your tenancy to read usage reports from the OCI tenancy
#
# Example policy:
# define tenancy usage-report as ocid1.tenancy.oc1..aaaaaaaaned4fkpkisbwjlr56u7cj63lf3wffbilvqknstgtvzub7vhqkggq
# endorse group group_name to read objects in tenancy usage-report
#
# Note - the only value you need to change is group name. Do not change the OCID in the first statement

	usage_report_namespace = 'bling'

	# Update these values
	destintation_path = 'downloaded_reports'

	# Make a directory to receive reports
	if not os.path.exists(destintation_path):
	os.mkdir(destintation_path)

	# Get the list of usage reports
	config = oci.config.from_file('config/config','DEFAULT')
	usage_report_bucket = config['tenancy']
	object_storage = oci.object_storage.ObjectStorageClient(config)
	report_bucket_objects = object_storage.list_objects(usage_report_namespace, usage_report_bucket)

	for o in report_bucket_objects.data.objects:
	   print('Found file ' + o.name)
	   object_details = object_storage.get_object(usage_report_namespace,usage_report_bucket,o.name)
	   filename = o.name.rsplit('/', 1)[-1]

	with open(destintation_path + '/' + filename, 'wb') as f:
	   for chunk in object_details.data.raw.stream(1024 * 1024, decode_content=False):
	      f.write(chunk)

	print('Finished downloading ' + o.name + '\n')
