//! Dynamic list experiment.
//!
//! Type an item, press Enter (or Add), see it appended. Delete
//! buttons on each row exercise scoped IDs: the row ID becomes
//! the first entry of the event scope, and we pick it up by
//! matching the scope inside `update`.

use plushie::prelude::*;

use super::Experiment;

pub struct ListExperiment {
    items: Vec<String>,
    draft: String,
    next_id: usize,
}

impl Default for ListExperiment {
    fn default() -> Self {
        Self {
            items: vec!["spam".into(), "eggs".into()],
            draft: String::new(),
            next_id: 1,
        }
    }
}

impl Experiment for ListExperiment {
    fn name(&self) -> &'static str {
        "list"
    }

    fn source(&self) -> &'static str {
        include_str!("list.rs")
    }

    fn view(&self) -> View {
        let mut rows = column().id("rows").spacing(4.0).width(Fill);
        for (index, item) in self.items.iter().enumerate() {
            let row_id = format!("item_{index}");
            rows = rows.child(
                row()
                    .id(&row_id)
                    .spacing(8.0)
                    .child(text(item))
                    .child(button("delete", "x")),
            );
        }

        column()
            .spacing(12.0)
            .padding(16)
            .width(Fill)
            .child(text("Dynamic list").id("title").size(18.0))
            .child(
                row()
                    .spacing(8.0)
                    .child(
                        text_input("draft", &self.draft)
                            .placeholder("Add an item")
                            .on_submit(true),
                    )
                    .child(button("add", "Add")),
            )
            .child(rows)
            .into()
    }

    fn update(&mut self, event: &Event) -> bool {
        match event.widget_match() {
            Some(Input("draft", value)) => {
                self.draft = value.to_string();
                true
            }
            Some(Submit("draft", _)) | Some(Click("add")) => {
                let trimmed = self.draft.trim();
                if trimmed.is_empty() {
                    return false;
                }
                self.items.push(trimmed.to_string());
                self.draft.clear();
                self.next_id += 1;
                true
            }
            Some(Click("delete")) => {
                // The preview wrapper scope is stripped before we get
                // here, so `scope()[0]` is the row's own ID (for
                // example `item_2`).
                let Some(scope) = event.scope() else {
                    return false;
                };
                let Some(row_id) = scope.first() else {
                    return false;
                };
                let Some(index) = row_id
                    .strip_prefix("item_")
                    .and_then(|s| s.parse::<usize>().ok())
                else {
                    return false;
                };
                if index < self.items.len() {
                    self.items.remove(index);
                    return true;
                }
                false
            }
            _ => false,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use plushie::test::TestSession;

    struct ListApp;

    impl App for ListApp {
        type Model = ListExperiment;

        fn init() -> (Self::Model, Command) {
            (ListExperiment::default(), Command::none())
        }

        fn update(model: &mut Self::Model, event: Event) -> Command {
            model.update(&event);
            Command::none()
        }

        fn view(model: &Self::Model, _w: &mut WidgetRegistrar) -> ViewList {
            window("main").child(model.view()).into()
        }
    }

    #[test]
    fn starts_with_two_items() {
        let session = TestSession::<ListApp>::start();
        assert_eq!(session.model().items, vec!["spam", "eggs"]);
    }

    #[test]
    fn starts_with_empty_draft() {
        let session = TestSession::<ListApp>::start();
        assert_eq!(session.model().draft, "");
    }

    #[test]
    fn typing_updates_draft() {
        let mut session = TestSession::<ListApp>::start();
        session.type_text("draft", "beans");
        assert_eq!(session.model().draft, "beans");
    }

    #[test]
    fn add_button_appends_item_and_clears_draft() {
        let mut session = TestSession::<ListApp>::start();
        session.type_text("draft", "beans");
        session.click("add");
        assert_eq!(session.model().items, vec!["spam", "eggs", "beans"]);
        assert_eq!(session.model().draft, "");
    }

    #[test]
    fn submit_on_draft_appends_item() {
        let mut session = TestSession::<ListApp>::start();
        session.type_text("draft", "toast");
        session.submit("draft");
        assert_eq!(session.model().items, vec!["spam", "eggs", "toast"]);
    }

    #[test]
    fn add_with_empty_draft_is_noop() {
        let mut session = TestSession::<ListApp>::start();
        session.click("add");
        assert_eq!(session.model().items.len(), 2);
    }

    #[test]
    fn add_trims_whitespace() {
        let mut session = TestSession::<ListApp>::start();
        session.type_text("draft", "  shrubbery  ");
        session.click("add");
        assert_eq!(session.model().items.last().unwrap(), "shrubbery");
    }

    #[test]
    fn delete_first_item_via_scoped_id() {
        let mut session = TestSession::<ListApp>::start();
        // "item_0/delete" scopes the click to the first row
        session.click("item_0/delete");
        assert_eq!(session.model().items, vec!["eggs"]);
    }

    #[test]
    fn delete_second_item_via_scoped_id() {
        let mut session = TestSession::<ListApp>::start();
        session.click("item_1/delete");
        assert_eq!(session.model().items, vec!["spam"]);
    }

    #[test]
    fn title_widget_exists() {
        let session = TestSession::<ListApp>::start();
        session.assert_exists("title");
    }

    #[test]
    fn name_is_list() {
        assert_eq!(ListExperiment::default().name(), "list");
    }
}
