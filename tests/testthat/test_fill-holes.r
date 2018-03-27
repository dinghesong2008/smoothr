context("fill_holes()")
library(sf)
library(units)

test_that("fill_holes() works", {
  p <- jagged_polygons$geometry[5]
  # remove hole
  p_filled <- fill_holes(p, threshold = units::set_units(1000, km^2))
  expect_true(st_area(p) < st_area(p_filled))
  # don't remove hole
  p_filled <- fill_holes(p, threshold = units::set_units(100, km^2))
  expect_true(st_area(p) == st_area(p_filled))
})

test_that("fill_holes() doesn't alter polygons with no holes", {
  p <- jagged_polygons[!jagged_polygons$hole, ]
  p_filled <- fill_holes(p, threshold = units::set_units(1e12, km^2))
  expect_equivalent(p, p_filled)
})

test_that("fill_holes() works for different input formats", {
  s_sf <- fill_holes(jagged_polygons, threshold = 2e8)
  s_sfc <- fill_holes(st_geometry(jagged_polygons), threshold = 2e8)
  s_spdf <- fill_holes(as(jagged_polygons, "Spatial"), threshold = 2e8)
  s_sp <- fill_holes(as(as(jagged_polygons, "Spatial"), "SpatialPolygons"),
                      threshold = 2e8)
  expect_s3_class(s_sf, "sf")
  expect_s3_class(s_sfc, "sfc")
  expect_s4_class(s_spdf, "SpatialPolygonsDataFrame")
  expect_s4_class(s_sp, "SpatialPolygons")
  expect_equal(st_area(s_sf), st_area(s_sfc))
  expect_equal(st_area(s_sf), st_area(st_as_sf(s_spdf)))
  expect_equivalent(st_set_geometry(s_sf, NULL), s_spdf@data)
})

test_that("fill_holes() fails for points and lines", {
  point <- st_point(c(0, 0)) %>%
    st_sfc()
  expect_error(fill_holes(point, threshold = 1))
  expect_error(fill_holes(as(st_sfc(point), "Spatial"), threshold = 1))

  expect_error(fill_holes(jagged_lines, threshold = 1))
  expect_error(fill_holes(as(jagged_lines, "Spatial"), threshold = 1))
})

test_that("fill_holes() fails for invalid thresholds", {
  expect_error(fill_holes(jagged_polygons, threshold = -1))
  expect_error(fill_holes(jagged_polygons, threshold = 0))
  expect_error(fill_holes(jagged_polygons,
                           threshold = set_units(1, km)))
})
