# Pure functions shared by the social-context module and tests.
social_proxy <- function(population, national_poverty_pct, multiplier=1) {
  if (length(population)!=length(national_poverty_pct)) stop("Lengths differ")
  if (length(multiplier)!=1L || !is.finite(multiplier) || multiplier<0 || multiplier>1) stop("Invalid multiplier")
  valid <- is.finite(population) & population>=0 & is.finite(national_poverty_pct) &
    national_poverty_pct>=0 & national_poverty_pct<=100
  out <- rep(NA_real_,length(population))
  out[valid] <- population[valid]*national_poverty_pct[valid]/100*multiplier
  out
}

social_weighted_rate <- function(population, national_poverty_pct) {
  proxy <- social_proxy(population,national_poverty_pct)
  valid <- is.finite(proxy)
  if (!any(valid) || sum(population[valid])<=0) return(NA_real_)
  100*sum(proxy[valid])/sum(population[valid])
}
