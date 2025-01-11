#!/bin/bash

# Search for any definitions of "uint256[N] private __gap" in files that end with "Storage.sol" in the src/contracts/ directory
grep -r "uint256\[[0-9]*\] private __gap" src/contracts/ | grep "Storage.sol" | while read -r line; do
  # Extract the contract file path from the grep output
  contract_file=$(echo "$line" | cut -d: -f1)
  
  # Extract the contract name without the ".sol" extension
  contract_name=$(basename "$contract_file" .sol)

  # Run forge inspect for the specific contract to generate storage information in JSON format and parse it directly
  echo "Inspecting contract: $contract_name"
  
  # Get all unique slot values
  unique_slots=$(forge inspect "$contract_name" storage --json | jq -r '.storage | map(.slot) | unique | length')

  # Subtract 1 to account for the gap variable
  unique_slots=$((unique_slots - 1))

  # Calculate the storage gap as 50 - total number of unique slots
  storage_gap=$((50 - unique_slots))

  # Output the storage gap
  echo "Contract: $contract_name - Storage gap: $storage_gap"

  # Update the __gap variable in the contract file
  sed -i '' "s/uint256\[[0-9]*\] private __gap;/uint256\[$storage_gap\] private __gap;/" "$contract_file"
  
  # Output the update confirmation
  echo "Updated __gap variable in $contract_name to uint256[$storage_gap] private __gap;"
done
