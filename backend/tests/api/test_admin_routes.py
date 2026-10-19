def test_run_db_optimization_endpoint_removed(client, admin_headers):
    """MT-458: the broken /admin/run-db-optimization endpoint is gone."""
    response = client.post("/admin/run-db-optimization", headers=admin_headers)
    assert response.status_code == 404


def test_add_missing_columns_endpoint_still_exists(client, admin_headers):
    """The sibling admin endpoint is untouched (405 on GET proves the route)."""
    response = client.get("/admin/add-missing-columns", headers=admin_headers)
    assert response.status_code == 405
