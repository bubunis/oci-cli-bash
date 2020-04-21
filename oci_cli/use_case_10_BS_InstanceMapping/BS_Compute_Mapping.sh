
oci compute instance list -c ocid1.compartment.oc1..aaaaaaaagctfina6fj36f7tgr5gaf6zo5c2r5ijz4aakm3x2ive3jdwyv45a | jq -C -r '.data[]|"\(."display-name") \(."source-details"."boot-volume-id")"'|column -t

oci bv boot-volume-backup list -c ocid1.compartment.oc1..aaaaaaaagctfina6fj36f7tgr5gaf6zo5c2r5ijz4aakm3x2ive3jdwyv45a | jq -C -r '.data[]|"\(."boot-volume-id") \(."lifecycle-state") \(."size-in-gbs") \(."expiration-time")"'|column -t
