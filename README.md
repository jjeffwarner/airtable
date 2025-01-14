A simple ruby program to take the exported data from Jira Plan and update the Airtable project.

## Installation
`gem install bundler && bundle install`

## Configuration
1. Create a `.env-collab-projects` and `.env-play-collab` file in the root directory.
2. Add the following to the `.env-collab-projects` file:
```
PERSONAL_ACCESS_TOKEN=your_airtable_api_key
AIRTABLE_TASK_API_URL=api/Tasks
AIRTABLE_EPIC_API_URL=api/Epics
CSV_FILE=your_csv_file
```
3. Add the same values in the `.env-play-collab` file.
4. The play-collab is the testing base. The collab-projects is the production base.

## Usage
Run `bundle exec rake` to run the tests

Run `bundle exec rake run` to run the program. This will also copy the `.env-collab-projects` file to `.env` and run the program.

Run `bundle exec rake play` to run the program with the play-collab base. This will also copy the `.env-play-collab` file to `.env` and run the program.

## Troubleshooting
Jan 13, 2025 - I ran brew upgrade which changed ruby from 3.4.0 to 3.4.1 which broke rake. It was complaining about versions. The final answer was running `bundle update rake`. I also switched from rvm to rbenv and 
discovered I needed to run `rbenv init` to get the ~./zshprofile updated with the path. Rather annoying 
use of my evening.

## Development


## Contributing
N/A

## License
N/A

## Notes
1. The CSV file is an export from the Jira plan.
1. Field values in Airtable are looking for an exact case match on the CSV values. It is easiest to adjust the Airtable values.
1. The script will update the Airtable record if the Jira ID is found in the Airtable record.
1. The script will add a new record if the Jira ID is not found in the Airtable record.
1. Really helpful link https://airtable.com/appbouPQCNCK9sqIb/api/docs#curl/introduction
1. The script will not delete records from Airtable.
1. The update script skips CSV rows that are hierarchical Epic type. They are the epics.


## Resources
https://dev.to/deciduously/setting-up-a-fresh-ruby-project-56o4

