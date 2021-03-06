% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ncaa_parse_pbp.R
\name{.ncaa_parse_pbp}
\alias{.ncaa_parse_pbp}
\title{Internal function to clean the raw pbp that is pulled in the intial stages of ncaa_get_pbp}
\usage{
.ncaa_parse_pbp(pbp_data_frame)
}
\arguments{
\item{season}{True or False, NCAA PBP by Season or Individual Teams.}

\item{division}{Select what division of college baseball}

\item{teamid}{The numerical ID that the NCAA website uses to identify a team}

\item{conf}{Select a conference, naming convention can be found in master_ncaa_team_lu}
}
\description{
Internal function to clean the raw pbp that is pulled in the intial stages of ncaa_get_pbp
}
\examples{

 \dontrun{
ncaa_parse_pbp(temp_df)
}
}
\keyword{NCAA,}
\keyword{baseball,}
\keyword{college,}
\keyword{internal}
