library(sp)
library(raster)
library(tidyverse)
library(sf)
set.seed(2)

# create some rasterized concentric circles to test smoothing on
r <- raster(nrows = 9, ncols = 9, xmn = 0, xmx = 1, ymn = 0, ymx = 1)
circle <- function(radius, r) {
  st_as_sfc("SRID=4326;POINT(0.5 0.5)") %>%
    st_buffer(radius) %>%
    as("Spatial") %>%
    rasterize(r)
}
# raster circles
radii <- seq(0.05, 0.45, by = 0.1)
layer_names <- paste0("polygon_", seq_along(radii))
circles <- radii %>%
  map(circle, r = r) %>%
  stack() %>%
  setNames(layer_names)
# convert back to jagged polygons
circles_poly <- map(1:nlayers(circles),
                    ~ rasterToPolygons(circles[[.x]], dissolve = TRUE)) %>%
  map(~ st_as_sf(.x) %>% select(geometry)) %>%
  do.call(rbind, .) %>%
  mutate(type = "polygon", hole = FALSE, multipart = FALSE)
circles_poly <- circles_poly[c(1, 2, 5), ]

# a more complicated shape
# from: https://gis.stackexchange.com/questions/24827/#24929
n <- 10
theta <- (runif(n) + 1:n - 1) * 2 * pi / n
radius <- rgamma(n, shape = 3)
radius <- radius / max(radius)
xy <- cbind(cos(theta) * radius, sin(theta) * radius)
xy <- rbind(xy, xy[1, ])
xy[, 1] <- xy[, 1] %>% {(. - min(.)) / (max(.) - min(.))}
xy[, 2] <- xy[, 2] %>% {(. - min(.)) / (max(.) - min(.))}
ply <- st_polygon(list(xy)) %>%
  st_sfc(crs = 4326) %>%
  st_sf(geometry = .) %>%
  mutate(type = "polygon", hole = FALSE, multipart = FALSE)

# circles with holes
chole <- map(4:5, ~ mask(circles[[.x]], circles[[.x - 2]], inverse = TRUE)) %>%
  stack() %>%
  setNames(paste0("hole_polygon_", 1:nlayers(.)))
# convert to jagged polygons
chole_poly <- map(1:nlayers(chole),
                  ~ rasterToPolygons(chole[[.x]], dissolve = TRUE)) %>%
  map(~ st_as_sf(.x) %>% select(geometry)) %>%
  do.call(rbind, .) %>%
  mutate(type = "polygon", hole = TRUE, multipart = FALSE)

# multipart polygons
r_mp1 <- r
r_mp1[sample.int(ncell(r), 9)] <- 1
mp1 <- rasterToPolygons(r_mp1, dissolve = TRUE) %>%
  st_as_sf() %>%
  select(geometry) %>%
  mutate(type = "polygon", hole = FALSE, multipart = TRUE)
r_mp2 <- r
r_mp2[c(1:9 + 0:8 * 9, 8 * 9 + 1, 9)] <- 1
mp2 <- rasterToPolygons(r_mp2, dissolve = TRUE) %>%
  st_as_sf() %>%
  select(geometry) %>%
  mutate(type = "polygon", hole = FALSE, multipart = TRUE)
mp3 <- rbind(chole_poly[2, ], circles_poly[2, ]) %>%
  st_combine() %>%
  st_sf(geometry = .) %>%
  mutate(type = "polygon", hole = TRUE, multipart = TRUE)
mp <- rbind(mp1, mp2, mp3)

# output
jagged_polygons <- rbind(circles_poly, ply, chole_poly, mp) %>%
  mutate(id = row_number()) %>%
  select(id, everything())
jagged_polygons %>%
  mutate_if(is.logical, as.character) %>%
  write_sf("data-raw/jagged_polygons.gpkg")
usethis::use_data(jagged_polygons, overwrite = TRUE)

# lines
# open
x <- seq(0, 1, by = 0.25)
l1 <- st_linestring(cbind(x, x^4))
x <- seq(0, 1, by = 0.2)
l2 <- st_linestring(cbind(x, 0.5 * sin(2 * pi * x) + 0.5))
x <- seq(0, 1, by = 0.05)
l3 <- st_linestring(cbind(x, 0.5 * sin(8 * pi * x) + 0.5))
open_lines <- st_sfc(list(l1, l2, l3), crs = 4326) %>%
  st_sf(geometry = .) %>%
  mutate(type = "line", closed = FALSE, multipart = FALSE)
# closed
closed_lines <- st_cast(circles_poly, "LINESTRING") %>%
  mutate(type = "line", closed = TRUE, multipart = FALSE) %>%
  select(type, closed, multipart)
# multipart
mls1 <- open_lines[1:2, ] %>%
  st_combine() %>%
  st_sf(geometry = .) %>%
  mutate(type = "line", closed = FALSE, multipart = TRUE)
x <- seq(0, 1, by = 0.25)
mls2 <- list(cbind(x, -2 * x * (x - 1)), cbind(x, -x^2 + 1)) %>%
  st_multilinestring() %>%
  st_sfc(crs = 4326) %>%
  st_sf(geometry = .) %>%
  mutate(type = "line", closed = FALSE, multipart = TRUE)
mls3 <- closed_lines[2:3, ] %>%
  st_combine() %>%
  st_sf(geometry = .) %>%
  mutate(type = "line", closed = TRUE, multipart = TRUE)
mls <- rbind(mls1, mls2, mls3)
# output
jagged_lines <- rbind(open_lines, closed_lines, mls) %>%
  mutate(id = row_number()) %>%
  select(id, everything())
jagged_lines %>%
  mutate_if(is.logical, as.character) %>%
  write_sf("data-raw/jagged_lines.gpkg")
usethis::use_data(jagged_lines, overwrite = TRUE)