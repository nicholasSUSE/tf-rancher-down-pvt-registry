#!/bin/bash

for resource in $(terraform state list); do
    if terraform state show "$resource" | grep -q "(tainted)"; then
        echo "Tainted resource found: $resource"
    fi
done
