function open(searchText, actions) {
	if (searchText !== "") actions.clearSearch();
	actions.refreshApplications();
	actions.resetSelection();
	actions.show();
	actions.scheduleFocus();
}
