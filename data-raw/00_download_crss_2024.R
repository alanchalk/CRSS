# Download the official 2024 Crash Report Sampling System (CRSS) CSV files.
#
# Run this script from the CRSS package root:
#   Rscript data-raw/00_download_crss_2024.R

crss_download_page_url <-
  "https://www.nhtsa.gov/file-downloads?p=nhtsa/downloads/CRSS/2024/"

crss_csv_url <-
  "https://static.nhtsa.gov/nhtsa/downloads/CRSS/2024/CRSS2024CSV.zip"

destination_directory <- "data-raw"
archive_file <- file.path(destination_directory, basename(crss_csv_url))
extraction_directory <- file.path(destination_directory, "CRSS2024CSV")

expected_files <- file.path(
  extraction_directory,
  c("accident.csv", "vehicle.csv", "person.csv")
)

# Size of the file downloaded on 2026-10-07. This check detects incomplete
# downloads and alerts us if NHTSA replaces the release in place.
expected_size_bytes <- 50891020

dir.create(destination_directory, recursive = TRUE, showWarnings = FALSE)

if (all(file.exists(expected_files))) {
  message("CRSS 2024 CSV files are already extracted: ", extraction_directory)
  quit(save = "no", status = 0)
}

if (dir.exists(extraction_directory)) {
  message("Removing incomplete extraction: ", extraction_directory)
  unlink(extraction_directory, recursive = TRUE)
}

if (!file.exists(archive_file)) {
  message("NHTSA download page: ", crss_download_page_url)
  message("Downloading ", crss_csv_url)

  download.file(
    url = crss_csv_url,
    destfile = archive_file,
    method = "libcurl",
    mode = "wb",
    quiet = FALSE
  )
} else {
  message("Using existing archive: ", archive_file)
}

actual_size_bytes <- file.info(archive_file)$size

if (is.na(actual_size_bytes) || actual_size_bytes != expected_size_bytes) {
  stop(
    "Unexpected file size for ", archive_file, ". Expected ",
    expected_size_bytes, " bytes but found ", actual_size_bytes,
    ". The download may be incomplete or NHTSA may have updated the release."
  )
}

message("Download verified: ", archive_file)
message("Extracting CSV files into ", destination_directory)

unzip(archive_file, exdir = destination_directory)

missing_files <- expected_files[!file.exists(expected_files)]

if (length(missing_files) > 0) {
  stop(
    "Extraction did not produce the expected files: ",
    paste(missing_files, collapse = ", "),
    ". The ZIP archive has been retained for diagnosis."
  )
}

if (!file.remove(archive_file)) {
  warning("Extraction succeeded, but the ZIP archive could not be deleted: ", archive_file)
}

message("Extraction verified: ", extraction_directory)
